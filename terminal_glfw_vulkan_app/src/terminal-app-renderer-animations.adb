with Ada.Real_Time;
with Interfaces;
with Terminal.App.Image_Animation;
with Terminal.App.Image_Store;
with Terminal.App.Image_Store.Frames;
with Terminal.App.Image_Store.Playback_State;
with Terminal.App.Image_Store.Themes;
with Terminal.App.Renderer.Image_Objects;
with Terminal.App.Renderer.Placement_State;
with Terminal.App.Renderer.Theme_State;
with Terminal.App.Renderer.Visual_Style;
with Terminal.App.Renderer.Animation_Frame_Canvas;
with Terminal.App.Renderer.Animation_Frame_Decoding;
with Terminal.Common.Counters;

package body Terminal.App.Renderer.Animations is
   package RM renames Terminal.App.Render_Model;
   package Themes renames Terminal.App.Image_Store.Themes;
   package Frames renames Terminal.App.Image_Store.Frames;
   package Playback_State renames Terminal.App.Image_Store.Playback_State;
   package Objects renames Terminal.App.Renderer.Image_Objects;
   package Placements renames Terminal.App.Renderer.Placement_State;
   package Image_Theme_State renames Terminal.App.Renderer.Theme_State;
   package Style renames Terminal.App.Renderer.Visual_Style;

   use type Ada.Real_Time.Time;
   use type Interfaces.Unsigned_64;
   use type Terminal.App.Image_Store.Animation_Playback_State;
   use type Terminal.App.Image_Animation.Control_Result;
   use type Terminal.App.Image_Store.Image_Frame_Access;
   use type Terminal.App.Image_Store.Image_Object_Access;
   use type Terminal.App.Image_Store.Theme_Operation_Access;
   use type Terminal.Core.Graphics_Stream_ID;
   use type Terminal.Core.Graphics_Screen_Generation;
   use type Terminal.Core.Graphics_ID;

   procedure Composite_Frame
     (R      : in out Renderer;
      Object : Image_Object_Access;
      Header : Terminal.App.Graphics.Graphics_Header;
      Data   : Terminal.App.Graphics.Graphics_Data_Preview;
      Canvas : in out Terminal.App.Owned_Image_Data.Owner) is separate;
   procedure Apply_Frame
     (R      : in out Renderer;
      Event  : Terminal.Core.Graphics_Event;
      Header : Terminal.App.Graphics.Graphics_Header;
      Text   : String;
      Allow_Unknown_Compressed_PNG_Size : Boolean := False) is separate;
   procedure Apply_Composition
     (R      : in out Renderer;
      Event  : Terminal.Core.Graphics_Event;
      Header : Terminal.App.Graphics.Graphics_Header) is separate;

   type Object_Slot is record
      Stream_ID : Terminal.Core.Graphics_Stream_ID := 0;
      Storage_Order : Interfaces.Unsigned_64 := 0;
      Object : Image_Object_Access := null;
      Visible : Boolean := False;
   end record;
   Object_Index_Length : constant Positive := Max_Kitty_Image_Objects * 2;
   type Object_Index is
     array (Natural range 0 .. Object_Index_Length - 1) of Object_Slot;

   function Hash
     (Stream_ID     : Terminal.Core.Graphics_Stream_ID;
      Storage_Order : Interfaces.Unsigned_64) return Natural
   is
      Value : Interfaces.Unsigned_64 :=
        Storage_Order
        xor Interfaces.Unsigned_64 (Stream_ID) * 16#9E37_79B9_7F4A_7C15#;
   begin
      Value := (Value xor Interfaces.Shift_Right (Value, 30))
        * 16#BF58_476D_1CE4_E5B9#;
      Value := (Value xor Interfaces.Shift_Right (Value, 27))
        * 16#94D0_49BB_1331_11EB#;
      Value := Value xor Interfaces.Shift_Right (Value, 31);
      return Natural (Value mod Interfaces.Unsigned_64 (Object_Index_Length));
   end Hash;

   procedure Insert
     (Index  : in out Object_Index;
      Object : Image_Object_Access)
   is
      Position : Natural := Hash (Object.Stream_ID, Object.Storage_Order);
   begin
      for Probe in 1 .. Index'Length loop
         pragma Unreferenced (Probe);
         if Index (Position).Object = null then
            Index (Position) :=
              (Stream_ID     => Object.Stream_ID,
               Storage_Order => Object.Storage_Order,
               Object        => Object,
               Visible       => False);
            return;
         end if;
         Position := (Position + 1) mod Index'Length;
      end loop;
      raise Program_Error with "animation object index is full";
   end Insert;

   procedure Mark_Visible
     (Index         : in out Object_Index;
      Stream_ID     : Terminal.Core.Graphics_Stream_ID;
      Storage_Order : Interfaces.Unsigned_64)
   is
      Position : Natural := Hash (Stream_ID, Storage_Order);
   begin
      for Probe in 1 .. Index'Length loop
         pragma Unreferenced (Probe);
         if Index (Position).Object = null then
            return;
         elsif Index (Position).Stream_ID = Stream_ID
           and then Index (Position).Storage_Order = Storage_Order
         then
            Index (Position).Visible := True;
            return;
         end if;
         Position := (Position + 1) mod Index'Length;
      end loop;
   end Mark_Visible;

   function Is_Visible
     (Index  : Object_Index;
      Object : Image_Object_Access) return Boolean
   is
      Position : Natural;
   begin
      if Object = null then
         return False;
      end if;
      Position := Hash (Object.Stream_ID, Object.Storage_Order);
      for Probe in 1 .. Index'Length loop
         pragma Unreferenced (Probe);
         if Index (Position).Object = null then
            return False;
         elsif Index (Position).Stream_ID = Object.Stream_ID
           and then Index (Position).Storage_Order = Object.Storage_Order
         then
            return Index (Position).Visible;
         end if;
         Position := (Position + 1) mod Index'Length;
      end loop;
      return False;
   end Is_Visible;

   procedure Build_Visibility_Index
     (R     : Renderer;
      Index : out Object_Index)
   is
      Object : Image_Object_Access := Terminal.App.Image_Store.First
        (R.Graphics_State.Resources.Image_Objects);

      procedure Mark
        (Stream_ID     : Terminal.Core.Graphics_Stream_ID;
         Storage_Order : Interfaces.Unsigned_64) is
      begin
         Mark_Visible (Index, Stream_ID, Storage_Order);
      end Mark;
   begin
      Index := (others => <>);
      while Object /= null loop
         Insert (Index, Object);
         Object := Terminal.App.Image_Store.Next_Object (Object);
      end loop;
      Placements.For_Each_Visible_Image_Object (R, Mark'Access);
   end Build_Visibility_Index;

   function Frame_Info
     (Object : Image_Object_Access;
      Number : Positive) return Frames.Frame_Descriptor
      renames Frames.Descriptor;

   function Frame_Exists
     (Object : Image_Object_Access;
      Number : Natural) return Boolean
      renames Frames.Exists;

   procedure Visit_Frame_Bytes
     (Object : Image_Object_Access;
      Number : Positive;
      Borrow : in out Terminal.App.Image_Store.Data_Borrow;
      Process : not null access procedure
        (Data : Terminal.Common.Bytes.Byte_Array))
   is
   begin
      Terminal.App.Image_Store.Release (Borrow);
      Terminal.App.Image_Store.Borrow (Borrow, Object);
      Terminal.App.Image_Store.Visit_Borrowed_Frame_Data
        (Borrow, Number, Process);
   end Visit_Frame_Bytes;

   function Set_Frame_Gap
     (R      : in out Renderer;
      Object : Image_Object_Access;
      Number : Positive;
      Gap    : Integer) return Boolean is
     (Frames.Set_Gap
        (R.Graphics_State.Resources.Image_Objects, Object, Number, Gap));

   function Set_Frame_Usage_Hint
     (R      : in out Renderer;
      Object : Image_Object_Access;
      Number : Positive;
      Value  : Natural) return Boolean is
     (Frames.Set_Usage_Hint
        (R.Graphics_State.Resources.Image_Objects, Object, Number, Value));

   procedure Copy_Frame_To_RGBA
     (Object : Image_Object_Access;
      Number : Positive;
      Target : in out Terminal.Common.Bytes.Byte_Array;
      Valid  : out Boolean)
      renames Frames.Copy_To_RGBA;

   procedure Visit_Display_Bytes
     (Object : Image_Object_Access;
      Borrow : in out Terminal.App.Image_Store.Data_Borrow;
      Process : not null access procedure
        (Data : Terminal.Common.Bytes.Byte_Array))
   is
   begin
      if Object = null then
         Terminal.App.Image_Store.Release (Borrow);
         return;
      end if;
      Visit_Frame_Bytes
        (Object, Playback_State.Current_Frame (Object.all), Borrow,
         Process);
   end Visit_Display_Bytes;

   function Display_Frame (Object : Image_Object_Access) return Positive is
     (if Object = null then 1
      else Playback_State.Current_Frame (Object.all));

   function Display_Format (Object : Image_Object_Access) return Natural is
     (if Object = null then 0
      elsif Playback_State.Current_Frame (Object.all) = 1 then Object.Raw_Format
      else 32);

   function Display_Length (Object : Image_Object_Access) return Natural is
     (if Object = null then 0
      elsif Playback_State.Current_Frame (Object.all) = 1
      then Object.Decoded_Length
      else Object.Pixel_Width * Object.Pixel_Height * 4);

   function Display_Stride (Object : Image_Object_Access) return Natural is
     (if Object = null then 0
      elsif Playback_State.Current_Frame (Object.all) = 1
      then Object.Decoded_Row_Stride_Bytes
      else Object.Pixel_Width * 4);

   procedure Delete_Frames
     (R : in out Renderer; Object : Image_Object_Access)
   is
      Max_Theme_Operations : constant Natural :=
        Max_Kitty_Animation_Frames * 4;
   begin
      if Object = null then
         return;
      end if;
      if Themes.Count (Object) > 0 then
         Themes.Archive_Root
           (R.Graphics_State.Resources.Image_Objects,
            Object,
            Max_Theme_Operations);
      end if;
      Frames.Clear
        (R.Graphics_State.Resources.Image_Objects, Object);
      Playback_State.Reset (Object);
      Terminal.App.Image_Store.Touch
        (R.Graphics_State.Resources.Image_Objects, Object);
      R.Graphics_State.Animation_Schedule_Valid := False;
   end Delete_Frames;

   procedure Apply_Control
     (R      : in out Renderer;
      Event  : Terminal.Core.Graphics_Event;
      Header : Terminal.App.Graphics.Graphics_Header)
   is
      Object : constant Image_Object_Access :=
        Objects.Find (R, Event.Stream_ID, Header.Kitty_ID);
      Control : Terminal.App.Image_Animation.Animation_Control;
      Result  : Terminal.App.Image_Animation.Control_Result;
   begin
      if Header.Kitty_Animation_State > 3 then
         R.Graphics_State.Transaction.Last_Animation_Result :=
           Terminal.Core.Graphics_EINVAL;
         return;
      end if;
      Control :=
        (Frame_Number => Header.Kitty_Frame_Number,
         Frame_Gap    => Header.Kitty_Frame_Gap,
         Start_Frame  => Header.Kitty_Base_Frame,
         Loop_Count   => Header.Kitty_Loop_Count,
         State        =>
           (case Header.Kitty_Animation_State is
               when 1 => Terminal.App.Image_Animation.Stopped,
               when 2 => Terminal.App.Image_Animation.Loading,
               when 3 => Terminal.App.Image_Animation.Running,
               when others => Terminal.App.Image_Animation.Unchanged));
      Result := Terminal.App.Image_Animation.Apply_Control
        (R.Graphics_State.Resources.Image_Objects, Object, Control);
      R.Graphics_State.Transaction.Last_Animation_Result :=
        (case Result is
            when Terminal.App.Image_Animation.Control_Ok =>
               Terminal.Core.Graphics_OK,
            when Terminal.App.Image_Animation.Control_Invalid =>
               Terminal.Core.Graphics_EINVAL,
            when Terminal.App.Image_Animation.Control_Not_Found =>
               Terminal.Core.Graphics_ENOENT);
      if Result = Terminal.App.Image_Animation.Control_Ok then
         Terminal.App.Image_Store.Touch
           (R.Graphics_State.Resources.Image_Objects, Object);
         R.Graphics_State.Animation_Schedule_Valid := False;
      end if;
   end Apply_Control;

   procedure Rebuild_Schedule (R : in out Renderer) is
      Index : Object_Index;
      Object : Image_Object_Access;

      procedure Consider (Object : Image_Object_Access) is
         Deadline : Ada.Real_Time.Time;
      begin
         if Object = null
           or else Playback_State.Playback (Object.all) =
             Animation_Stopped
           or else Frames.Count (Object) <= 1
         then
            return;
         elsif not Playback_State.Deadline_Set (Object.all) then
            if Playback_State.Playback (Object.all) =
                Animation_Running
              or else Playback_State.Current_Frame (Object.all) <
                Frames.Count (Object)
            then
               R.Graphics_State.Animation_Schedule_Immediate := True;
            end if;
            return;
         end if;

         Deadline := Playback_State.Next_Frame_At (Object.all);
         if not R.Graphics_State.Animation_Schedule_Has_Deadline
           or else Deadline < R.Graphics_State.Animation_Schedule_Deadline
         then
            R.Graphics_State.Animation_Schedule_Has_Deadline := True;
            R.Graphics_State.Animation_Schedule_Deadline := Deadline;
         end if;
      end Consider;
   begin
      R.Graphics_State.Animation_Schedule_Immediate := False;
      R.Graphics_State.Animation_Schedule_Has_Deadline := False;
      R.Graphics_State.Animation_Schedule_Deadline := Ada.Real_Time.Time_First;
      Build_Visibility_Index (R, Index);
      Object := Terminal.App.Image_Store.First
        (R.Graphics_State.Resources.Image_Objects);
      while Object /= null loop
         if Is_Visible (Index, Object) then
            Consider (Object);
         end if;
         Object := Terminal.App.Image_Store.Next_Object (Object);
      end loop;
      R.Graphics_State.Animation_Schedule_Valid := True;
   end Rebuild_Schedule;

   function Frame_Due
     (R   : in out Renderer;
      Now : Ada.Real_Time.Time) return Boolean
   is
   begin
      if not R.Graphics_State.Animation_Schedule_Valid then
         Rebuild_Schedule (R);
      end if;
      if R.Graphics_State.Animation_Schedule_Immediate then
         return True;
      elsif R.Graphics_State.Animation_Schedule_Has_Deadline
        and then Now >= R.Graphics_State.Animation_Schedule_Deadline
      then
         R.Graphics_State.Animation_Schedule_Valid := False;
         return True;
      else
         return False;
      end if;
   end Frame_Due;

   function Frame_Due (R : in out Renderer) return Boolean is
     (Frame_Due (R, Ada.Real_Time.Clock));

   function Wait_Duration
     (R       : in out Renderer;
      Now     : Ada.Real_Time.Time;
      Maximum : Duration) return Duration is
   begin
      if not R.Graphics_State.Animation_Schedule_Valid then
         Rebuild_Schedule (R);
      end if;
      if R.Graphics_State.Animation_Schedule_Immediate then
         return 0.0;
      elsif R.Graphics_State.Animation_Schedule_Has_Deadline then
         return Duration'Min
           (Maximum,
            Duration'Max
              (0.0,
               Ada.Real_Time.To_Duration
                 (R.Graphics_State.Animation_Schedule_Deadline - Now)));
      else
         return Maximum;
      end if;
   end Wait_Duration;

   procedure Advance
     (R   : in out Renderer;
      Now : Ada.Real_Time.Time)
   is
      Index : Object_Index;
      Object : Image_Object_Access :=
        Terminal.App.Image_Store.First
          (R.Graphics_State.Resources.Image_Objects);
   begin
      R.Graphics_State.Animation_Schedule_Valid := False;
      Build_Visibility_Index (R, Index);
      while Object /= null loop
         declare
            Advances : constant Natural :=
              (if Is_Visible (Index, Object)
               then Terminal.App.Image_Animation.Advance (Object, Now)
               else 0);
         begin
            if Advances > 0 then
               Terminal.App.Image_Store.Mark_Content_Changed
                 (R.Graphics_State.Resources.Image_Objects, Object);
               Terminal.Common.Counters.Add_Saturating
                 (R.Graphics_State.Telemetry.Animation_Advance_Count,
                  Interfaces.Unsigned_64 (Advances));
            end if;
         end;
         Object := Terminal.App.Image_Store.Next_Object (Object);
      end loop;
   end Advance;

   procedure Advance (R : in out Renderer) is
   begin
      Advance (R, Ada.Real_Time.Clock);
   end Advance;
end Terminal.App.Renderer.Animations;
