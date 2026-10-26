with Ada.Containers.Vectors;
with Ada.Unchecked_Deallocation;
with Terminal.Common.Bytes;
with System;
with System.Storage_Elements;

package body Terminal.App.Image_Store is
   use type Interfaces.Unsigned_64;
   use type Terminal.App.Render_Model.Image_Data_Access;
   use type Terminal.App.Render_Model.Image_Data_View;
   use type Terminal.Core.Graphics_ID;
   use type Terminal.Core.Graphics_Stream_ID;
   use type System.Address;

   function Hash_Address (Value : System.Address) return Ada.Containers.Hash_Type is
     (Ada.Containers.Hash_Type'Mod
        (System.Storage_Elements.To_Integer (Value)));

   procedure Free_Image_Data is new Ada.Unchecked_Deallocation
     (Terminal.Common.Bytes.Byte_Array,
      Terminal.App.Render_Model.Image_Data_Access);
   procedure Free_Image_Frame is new Ada.Unchecked_Deallocation
     (Image_Frame, Image_Frame_Access);
   procedure Free_Theme_Operation is new Ada.Unchecked_Deallocation
     (Theme_Operation, Theme_Operation_Access);
   procedure Free_Image_Object is new Ada.Unchecked_Deallocation
     (Image_Object, Image_Object_Access);

   procedure Create_Object (Object : out Image_Object_Access) is
   begin
      Object := new Image_Object;
   end Create_Object;

   procedure Release_Unowned_Object (Object : in out Image_Object_Access) is
   begin
      if Object = null then
         return;
      elsif Object.Owner /= System.Null_Address
        or else Object.Next /= null
        or else Object.Counted
        or else Object.Replaces /= null
      then
         raise Program_Error with "cannot release an owned image object";
      end if;
      Release_Contents (Object.all);
      Free_Image_Object (Object);
   end Release_Unowned_Object;

   function Number (Frame : Image_Frame) return Positive is (Frame.Number);
   function Gap_MS (Frame : Image_Frame) return Integer is (Frame.Gap_MS);
   function Usage_Hint (Frame : Image_Frame) return Natural is
     (Frame.Usage_Hint);
   function Bytes
     (Frame : Image_Frame) return Terminal.App.Render_Model.Image_Data_View is
     (Terminal.App.Render_Model.Read_Only (Frame.Bytes));
   function Length (Frame : Image_Frame) return Natural is (Frame.Length);
   procedure Set_Usage_Hint
     (Frame : Image_Frame_Access; Value : Natural) is
   begin
      if Frame /= null then Frame.Usage_Hint := Value; end if;
   end Set_Usage_Hint;

   procedure Create_Frame
     (Number     : Positive;
      Gap_MS     : Integer;
      Usage_Hint : Natural;
      Data       : in out Terminal.App.Render_Model.Image_Data_Access;
      Frame      : out Image_Frame_Access) is
   begin
      Frame := null;
      if Data = null then
         raise Constraint_Error with "cannot create a frame without data";
      end if;
      Frame := new Image_Frame'
        (Number => Number, Gap_MS => Gap_MS, Usage_Hint => Usage_Hint,
         Bytes => Data, Length => Data'Length, Next => null);
      Data := null;
   end Create_Frame;

   procedure Append_Unowned_Frame
     (Head, Tail : in out Image_Frame_Access;
      Frame      : in out Image_Frame_Access) is
   begin
      if Frame = null or else Frame.Next /= null then
         raise Program_Error with "frame is null or already linked";
      elsif Head = null then
         Head := Frame;
      elsif Tail = null then
         raise Program_Error with "frame-list tail invariant violated";
      else
         Tail.Next := Frame;
      end if;
      Tail := Frame;
      Frame := null;
   end Append_Unowned_Frame;

   function Descriptor
     (Operation : Theme_Operation) return Theme_Operation_Descriptor is
     (Is_Composition => Operation.Is_Composition,
      Archived_Frames => Operation.Archived_Frames,
      New_Frame => Operation.New_Frame,
      Target_Frame => Operation.Target_Frame,
      Base_Frame => Operation.Base_Frame,
      Source_Frame => Operation.Source_Frame,
      Raw_Format => Operation.Raw_Format,
      Data_Width => Operation.Data_Width,
      Data_Height => Operation.Data_Height,
      Data_Row_Stride_Bytes => Operation.Data_Row_Stride_Bytes,
      Target_X => Operation.Target_X,
      Target_Y => Operation.Target_Y,
      Source_X => Operation.Source_X,
      Source_Y => Operation.Source_Y,
      Region_Width => Operation.Region_Width,
      Region_Height => Operation.Region_Height,
      Composition_Mode => Operation.Composition_Mode,
      Background_Color => Operation.Background_Color);
   function Bytes
     (Operation : Theme_Operation)
      return Terminal.App.Render_Model.Image_Data_View is
     (Terminal.App.Render_Model.Read_Only (Operation.Bytes));
   function Length (Operation : Theme_Operation) return Natural is
     (Operation.Length);
   function Is_Composition (Operation : Theme_Operation) return Boolean is
     (Operation.Is_Composition);
   function Archived_Frames (Operation : Theme_Operation) return Boolean is
     (Operation.Archived_Frames);
   function New_Frame (Operation : Theme_Operation) return Boolean is
     (Operation.New_Frame);
   function Target_Frame (Operation : Theme_Operation) return Positive is
     (Operation.Target_Frame);
   function Base_Frame (Operation : Theme_Operation) return Natural is
     (Operation.Base_Frame);
   function Source_Frame (Operation : Theme_Operation) return Natural is
     (Operation.Source_Frame);
   function Raw_Format (Operation : Theme_Operation) return Natural is
     (Operation.Raw_Format);
   function Data_Width (Operation : Theme_Operation) return Natural is
     (Operation.Data_Width);
   function Data_Height (Operation : Theme_Operation) return Natural is
     (Operation.Data_Height);
   function Data_Row_Stride_Bytes
     (Operation : Theme_Operation) return Natural is
     (Operation.Data_Row_Stride_Bytes);
   function Target_X (Operation : Theme_Operation) return Natural is
     (Operation.Target_X);
   function Target_Y (Operation : Theme_Operation) return Natural is
     (Operation.Target_Y);
   function Source_X (Operation : Theme_Operation) return Natural is
     (Operation.Source_X);
   function Source_Y (Operation : Theme_Operation) return Natural is
     (Operation.Source_Y);
   function Region_Width (Operation : Theme_Operation) return Natural is
     (Operation.Region_Width);
   function Region_Height (Operation : Theme_Operation) return Natural is
     (Operation.Region_Height);
   function Composition_Mode (Operation : Theme_Operation) return Natural is
     (Operation.Composition_Mode);
   function Background_Color
     (Operation : Theme_Operation) return Terminal.Core.Graphics_ID is
     (Operation.Background_Color);

   procedure Create_Theme_Operation
     (Description : Theme_Operation_Descriptor;
      Data        : in out Terminal.App.Render_Model.Image_Data_Access;
      Operation   : out Theme_Operation_Access) is
   begin
      Operation := new Theme_Operation'
        (Is_Composition => Description.Is_Composition,
         Archived_Frames => Description.Archived_Frames,
         New_Frame => Description.New_Frame,
         Target_Frame => Description.Target_Frame,
         Base_Frame => Description.Base_Frame,
         Source_Frame => Description.Source_Frame,
         Raw_Format => Description.Raw_Format,
         Data_Width => Description.Data_Width,
         Data_Height => Description.Data_Height,
         Data_Row_Stride_Bytes => Description.Data_Row_Stride_Bytes,
         Target_X => Description.Target_X,
         Target_Y => Description.Target_Y,
         Source_X => Description.Source_X,
         Source_Y => Description.Source_Y,
         Region_Width => Description.Region_Width,
         Region_Height => Description.Region_Height,
         Composition_Mode => Description.Composition_Mode,
         Background_Color => Description.Background_Color,
         Bytes => Data,
         Length => (if Data = null then 0 else Data'Length),
         Next => null);
      Data := null;
   end Create_Theme_Operation;

   procedure Append_Unowned_Theme_Operation
     (Head, Tail : in out Theme_Operation_Access;
      Operation  : in out Theme_Operation_Access) is
   begin
      if Operation = null or else Operation.Next /= null then
         raise Program_Error with "theme operation is null or already linked";
      elsif Head = null then
         Head := Operation;
      elsif Tail = null then
         raise Program_Error with "theme-list tail invariant violated";
      else
         Tail.Next := Operation;
      end if;
      Tail := Operation;
      Operation := null;
   end Append_Unowned_Theme_Operation;

   function Stream_ID (Object : Image_Object) return Terminal.Core.Graphics_Stream_ID is
     (Object.Stream_ID);
   function ID (Object : Image_Object) return Terminal.Core.Graphics_ID is
     (Object.ID);
   function Number (Object : Image_Object) return Terminal.Core.Graphics_ID is
     (Object.Number);
   function Protocol
     (Object : Image_Object) return Terminal.App.Render_Model.Image_Protocol is
     (Object.Protocol);
   function Raw_Format (Object : Image_Object) return Natural is
     (Object.Raw_Format);
   function Pixel_Width (Object : Image_Object) return Natural is
     (Object.Pixel_Width);
   function Pixel_Height (Object : Image_Object) return Natural is
     (Object.Pixel_Height);
   function Decoded_Length (Object : Image_Object) return Natural is
     (Object.Decoded_Length);
   function Decoded_Row_Stride_Bytes (Object : Image_Object) return Natural is
     (Object.Decoded_Row_Stride_Bytes);
   function Usage_Hint (Object : Image_Object) return Natural is
     (Object.Usage_Hint);
   function Storage_Order (Object : Image_Object) return Interfaces.Unsigned_64 is
     (Object.Storage_Order);
   function Content_Serial (Object : Image_Object) return Interfaces.Unsigned_64 is
     (Object.Content_Serial);
   function Root_Gap_MS (Object : Image_Object) return Integer is
     (Object.Root_Gap_MS);
   function Current_Frame (Object : Image_Object) return Positive is
     (Object.Current_Frame);
   function Playback (Object : Image_Object) return Animation_Playback_State is
     (Object.Playback);
   function Loop_Count (Object : Image_Object) return Positive is
     (Object.Loop_Count);
   function Loops_Completed (Object : Image_Object) return Natural is
     (Object.Loops_Completed);
   function Next_Frame_At (Object : Image_Object) return Ada.Real_Time.Time is
     (Object.Next_Frame_At);
   function Deadline_Set (Object : Image_Object) return Boolean is
     (Object.Deadline_Set);

   procedure Set_Usage_Hint
     (Object : Image_Object_Access; Value : Natural) is
   begin
      if Object /= null then Object.Usage_Hint := Value; end if;
   end Set_Usage_Hint;
   procedure Set_Root_Gap
     (Object : Image_Object_Access; Value : Integer) is
   begin
      if Object /= null then Object.Root_Gap_MS := Value; end if;
   end Set_Root_Gap;
   procedure Set_Current_Frame
     (Object : Image_Object_Access; Value : Positive) is
   begin
      if Object /= null and then Frame_Exists (Object, Value) then
         Object.Current_Frame := Value;
      end if;
   end Set_Current_Frame;
   procedure Set_Playback
     (Object : Image_Object_Access; Value : Animation_Playback_State) is
   begin
      if Object /= null then Object.Playback := Value; end if;
   end Set_Playback;
   procedure Set_Loop_Count
     (Object : Image_Object_Access; Value : Positive) is
   begin
      if Object /= null then Object.Loop_Count := Value; end if;
   end Set_Loop_Count;
   procedure Set_Loops_Completed
     (Object : Image_Object_Access; Value : Natural) is
   begin
      if Object /= null then Object.Loops_Completed := Value; end if;
   end Set_Loops_Completed;
   procedure Set_Next_Frame_At
     (Object : Image_Object_Access; Value : Ada.Real_Time.Time) is
   begin
      if Object /= null then Object.Next_Frame_At := Value; end if;
   end Set_Next_Frame_At;
   procedure Set_Deadline
     (Object : Image_Object_Access; Value : Boolean) is
   begin
      if Object /= null then Object.Deadline_Set := Value; end if;
   end Set_Deadline;

   procedure Release_Frame_List (Head : in out Image_Frame_Access) is
      Current : Image_Frame_Access := Head;
   begin
      while Current /= null loop
         declare
            Following : constant Image_Frame_Access := Current.Next;
         begin
            Free_Image_Data (Current.Bytes);
            Free_Image_Frame (Current);
            Current := Following;
         end;
      end loop;
      Head := null;
   end Release_Frame_List;

   procedure Release_Theme_Operation_List
     (Head : in out Theme_Operation_Access)
   is
      Current : Theme_Operation_Access := Head;
   begin
      while Current /= null loop
         declare
            Following : constant Theme_Operation_Access := Current.Next;
         begin
            Free_Image_Data (Current.Bytes);
            Free_Theme_Operation (Current);
            Current := Following;
         end;
      end loop;
      Head := null;
   end Release_Theme_Operation_List;

   procedure Release_Unowned_Frames (Head : in out Image_Frame_Access) is
   begin
      Release_Frame_List (Head);
   end Release_Unowned_Frames;

   procedure Release_Unowned_Theme_Operations
     (Head : in out Theme_Operation_Access) is
   begin
      Release_Theme_Operation_List (Head);
   end Release_Unowned_Theme_Operations;

   function Find_By_ID
     (Container : Store;
      Stream_ID : Terminal.Core.Graphics_Stream_ID;
      ID        : Terminal.Core.Graphics_ID) return Image_Object_Access
   is
      Current : Image_Object_Access := Container.Head;
   begin
      if ID = 0 then
         return null;
      end if;
      while Current /= null loop
         if Current.Stream_ID = Stream_ID and then Current.ID = ID then
            return Current;
         end if;
         Current := Current.Next;
      end loop;
      return null;
   end Find_By_ID;

   function Find_By_Number
     (Container : Store;
      Stream_ID : Terminal.Core.Graphics_Stream_ID;
      Number    : Terminal.Core.Graphics_ID) return Image_Object_Access
   is
      Current : Image_Object_Access := Container.Head;
   begin
      if Number = 0 then
         return null;
      end if;
      while Current /= null loop
         if Current.Stream_ID = Stream_ID and then Current.Number = Number then
            return Current;
         end if;
         Current := Current.Next;
      end loop;
      return null;
   end Find_By_Number;

   function Find_By_Storage_Order
     (Container     : Store;
      Stream_ID     : Terminal.Core.Graphics_Stream_ID;
      Storage_Order : Interfaces.Unsigned_64) return Image_Object_Access
   is
      Current : Image_Object_Access := Container.Head;
   begin
      if Storage_Order = 0 then
         return null;
      end if;
      while Current /= null loop
         if Current.Stream_ID = Stream_ID
           and then Current.Storage_Order = Storage_Order
         then
            return Current;
         end if;
         Current := Current.Next;
      end loop;
      return null;
   end Find_By_Storage_Order;

   function Owned_Bytes (Object : Image_Object) return Natural is
      Result : Natural := 0;

      procedure Add (Amount : Natural) is
      begin
         if Amount > Natural'Last - Result then
            Result := Natural'Last;
         else
            Result := Result + Amount;
         end if;
      end Add;
   begin
      if Object.Bytes /= null then
         Add (Object.Bytes'Length);
      end if;
      if Object.Indexed_Bytes /= null then
         Add (Object.Indexed_Bytes'Length);
      end if;
      Add (Object.Frame_Bytes);
      Add (Object.Theme_Operation_Bytes);
      return Result;
   end Owned_Bytes;

   function Root_Data
     (Object : Image_Object_Access)
      return Terminal.App.Render_Model.Image_Data_View is
     (if Object = null then null
      else Terminal.App.Render_Model.Read_Only (Object.Bytes));

   function Indexed_Data
     (Object : Image_Object_Access)
      return Terminal.App.Render_Model.Image_Data_View is
     (if Object = null then null
      else Terminal.App.Render_Model.Read_Only (Object.Indexed_Bytes));

   function Indexed_Data_Format
     (Object : Image_Object_Access) return Natural is
     (if Object = null then 0 else Object.Indexed_Format);

   function Indexed_Data_Length
     (Object : Image_Object_Access) return Natural is
     (if Object = null then 0 else Object.Indexed_Length);

   function Indexed_Row_Stride
     (Object : Image_Object_Access) return Natural is
     (if Object = null then 0 else Object.Indexed_Row_Stride_Bytes);

   function First_Frame
     (Object : Image_Object_Access) return Image_Frame_Access is
     (if Object = null then null else Object.Frames);

   function Next_Frame (Frame : Image_Frame_Access) return Image_Frame_Access is
     (if Frame = null then null else Frame.Next);

   function Frame_Count_Of (Object : Image_Object_Access) return Positive is
     (if Object = null then 1 else Object.Frame_Count);

   function First_Theme_Operation
     (Object : Image_Object_Access) return Theme_Operation_Access is
     (if Object = null then null else Object.Theme_Operations);

   function Next_Theme_Operation
     (Operation : Theme_Operation_Access) return Theme_Operation_Access is
     (if Operation = null then null else Operation.Next);

   function Theme_Operation_Count_Of
     (Object : Image_Object_Access) return Natural is
     (if Object = null then 0 else Object.Theme_Operation_Count);

   function Owned_Animation_Frames (Object : Image_Object) return Natural is
     (Object.Frame_Count - 1);

   function Owns_Data
     (Object : Image_Object_Access;
      Data   : Terminal.App.Render_Model.Image_Data_Access) return Boolean
   is
      Frame : Image_Frame_Access;
      Operation : Theme_Operation_Access;
   begin
      if Object = null or else Data = null then
         return False;
      elsif Data = Object.Bytes or else Data = Object.Indexed_Bytes then
         return True;
      end if;
      Frame := Object.Frames;
      while Frame /= null loop
         if Data = Frame.Bytes then
            return True;
         end if;
         Frame := Frame.Next;
      end loop;
      Operation := Object.Theme_Operations;
      while Operation /= null loop
         if Data = Operation.Bytes then
            return True;
         end if;
         Operation := Operation.Next;
      end loop;
      return False;
   end Owns_Data;

   function Owns_Non_Theme_Data
     (Object : Image_Object_Access;
      Data   : Terminal.App.Render_Model.Image_Data_Access) return Boolean
   is
      Frame : Image_Frame_Access;
   begin
      if Object = null or else Data = null then
         return False;
      elsif Data = Object.Bytes or else Data = Object.Indexed_Bytes then
         return True;
      end if;
      Frame := Object.Frames;
      while Frame /= null loop
         if Data = Frame.Bytes then
            return True;
         end if;
         Frame := Frame.Next;
      end loop;
      return False;
   end Owns_Non_Theme_Data;

   function Find_Frame
     (Object : Image_Object_Access;
      Number : Positive) return Image_Frame_Access
   is
      Current : Image_Frame_Access :=
        (if Object = null then null else Object.Frames);
   begin
      if Number = 1 then
         return null;
      end if;
      while Current /= null loop
         if Current.Number = Number then
            return Current;
         end if;
         Current := Current.Next;
      end loop;
      return null;
   end Find_Frame;

   function Frame_Exists
     (Object : Image_Object_Access;
      Number : Natural) return Boolean is
     (Object /= null
      and then Number in 1 .. Object.Frame_Count
      and then
        (Number = 1
         or else Find_Frame (Object, Positive (Number)) /= null));

   function Frame_Bytes
     (Object : Image_Object_Access;
      Number : Positive)
      return Terminal.App.Render_Model.Image_Data_View
   is
      Frame : constant Image_Frame_Access := Find_Frame (Object, Number);
   begin
      if Object = null then
         return null;
      elsif Number = 1 then
         return Terminal.App.Render_Model.Read_Only (Object.Bytes);
      else
         return
           (if Frame = null then null
            else Terminal.App.Render_Model.Read_Only (Frame.Bytes));
      end if;
   end Frame_Bytes;

   function Frame_Gap
     (Object : Image_Object_Access;
      Number : Positive) return Integer
   is
      Frame : constant Image_Frame_Access := Find_Frame (Object, Number);
   begin
      if Object = null then
         return 0;
      elsif Number = 1 then
         return Object.Root_Gap_MS;
      else
         return (if Frame = null then 0 else Frame.Gap_MS);
      end if;
   end Frame_Gap;

   function Set_Frame_Gap
     (Object : Image_Object_Access;
      Number : Positive;
      Gap    : Integer) return Boolean
   is
      Frame : constant Image_Frame_Access := Find_Frame (Object, Number);
   begin
      if Object = null then
         return False;
      elsif Number = 1 then
         Object.Root_Gap_MS := Gap;
         return True;
      elsif Frame /= null then
         Frame.Gap_MS := Gap;
         return True;
      end if;
      return False;
   end Set_Frame_Gap;

   procedure Copy_Frame_To_RGBA
     (Object : Image_Object_Access;
      Number : Positive;
      Target : in out Terminal.Common.Bytes.Byte_Array;
      Valid  : out Boolean)
   is
      Source : constant Terminal.App.Render_Model.Image_Data_View :=
        Frame_Bytes (Object, Number);
      Pixels : Natural;
   begin
      Valid := False;
      if Object = null
        or else Source = null
        or else Object.Pixel_Width = 0
        or else Object.Pixel_Height = 0
        or else Object.Pixel_Width > Natural'Last / Object.Pixel_Height
      then
         return;
      end if;
      Pixels := Object.Pixel_Width * Object.Pixel_Height;
      if Pixels > Natural'Last / 4
        or else Target'Length /= Pixels * 4
      then
         return;
      end if;
      if Number /= 1 or else Object.Raw_Format = 32 then
         if Source'Length < Target'Length then
            return;
         end if;
         Target := Source (Source'First .. Source'First + Target'Length - 1);
      elsif Object.Raw_Format = 24 then
         if Pixels > Natural'Last / 3
           or else Source'Length < Pixels * 3
         then
            return;
         end if;
         for Pixel in 0 .. Pixels - 1 loop
            Target (Target'First + Pixel * 4) :=
              Source (Source'First + Pixel * 3);
            Target (Target'First + Pixel * 4 + 1) :=
              Source (Source'First + Pixel * 3 + 1);
            Target (Target'First + Pixel * 4 + 2) :=
              Source (Source'First + Pixel * 3 + 2);
            Target (Target'First + Pixel * 4 + 3) := 255;
         end loop;
      else
         return;
      end if;
      Valid := True;
   end Copy_Frame_To_RGBA;

   procedure Release_Contents (Object : in out Image_Object) is
      Frame : Image_Frame_Access := Object.Frames;
      Operation : Theme_Operation_Access := Object.Theme_Operations;
      Next : constant Image_Object_Access := Object.Next;
      Counted : constant Boolean := Object.Counted;
      Replaces : constant Image_Object_Access := Object.Replaces;
      Accounted_Bytes : constant Natural := Object.Accounted_Bytes;
      Accounted_Frames : constant Natural := Object.Accounted_Frames;
      Owner : constant System.Address := Object.Owner;
   begin
      Release_Frame_List (Frame);
      Release_Theme_Operation_List (Operation);
      if Object.Bytes /= null then
         Free_Image_Data (Object.Bytes);
      end if;
      if Object.Indexed_Bytes /= null then
         Free_Image_Data (Object.Indexed_Bytes);
      end if;
      Object.Theme_Addresses.Clear;
      Object := (others => <>);
      Object.Next := Next;
      Object.Counted := Counted;
      Object.Replaces := Replaces;
      Object.Accounted_Bytes := Accounted_Bytes;
      Object.Accounted_Frames := Accounted_Frames;
      Object.Owner := Owner;
   end Release_Contents;

   function First (Container : Store) return Image_Object_Access is
     (Container.Head);

   function Next_Object
     (Object : Image_Object_Access) return Image_Object_Access is
     (if Object = null then null else Object.Next);

   function Object_Count (Container : Store) return Natural is
     (Container.Objects);

   function Byte_Count (Container : Store) return Natural is
     (Container.Bytes);

   function Animation_Frame_Count (Container : Store) return Natural is
     (Container.Animation_Frames);

   function Checked_Total (Left, Right : Natural) return Natural is
   begin
      if Right > Natural'Last - Left then
         raise Storage_Error with "image store accounting overflow";
      end if;
      return Left + Right;
   end Checked_Total;

   function Bytes_Per_Pixel (Format : Natural) return Natural is
     (case Format is
         when 8      => 1,
         when 16     => 2,
         when 24     => 3,
         when 32     => 4,
         when others => 0);

   procedure Validate_Pixel_Data
     (Format       : Natural;
      Pixel_Width  : Natural;
      Pixel_Height : Natural;
      Row_Stride   : Natural;
      Length       : Natural)
   is
      Pixel_Size : constant Natural := Bytes_Per_Pixel (Format);
      Minimum_Row : Natural;
   begin
      if Pixel_Size = 0 or else Pixel_Width = 0 or else Pixel_Height = 0 then
         raise Constraint_Error with "invalid image geometry or format";
      elsif Pixel_Width > Natural'Last / Pixel_Size then
         raise Constraint_Error with "image row size overflows";
      end if;
      Minimum_Row := Pixel_Width * Pixel_Size;
      if Row_Stride < Minimum_Row
        or else Row_Stride > Natural'Last / Pixel_Height
        or else Length /= Row_Stride * Pixel_Height
      then
         raise Constraint_Error with "image data does not match its layout";
      end if;
   end Validate_Pixel_Data;

   function Is_Owned
     (Container : Store;
      Object    : Image_Object_Access) return Boolean
   is (Object /= null and then Object.Owner = Container'Address);

   procedure Synchronize
     (Container : in out Store;
      Object    : Image_Object_Access)
   is
      New_Bytes : Natural;
      New_Frames : Natural;
      Remaining_Bytes : Natural;
      Remaining_Frames : Natural;
   begin
      if Object = null or else not Is_Owned (Container, Object) then
         raise Program_Error with "image object is not owned by this store";
      end if;
      New_Bytes := Owned_Bytes (Object.all);
      New_Frames := Owned_Animation_Frames (Object.all);
      Remaining_Bytes := Container.Bytes - Object.Accounted_Bytes;
      Remaining_Frames :=
        Container.Animation_Frames - Object.Accounted_Frames;
      declare
         Total_Bytes : constant Natural :=
           Checked_Total (Remaining_Bytes, New_Bytes);
         Total_Frames : constant Natural :=
           Checked_Total (Remaining_Frames, New_Frames);
      begin
         Container.Bytes := Total_Bytes;
         Container.Animation_Frames := Total_Frames;
         Object.Accounted_Bytes := New_Bytes;
         Object.Accounted_Frames := New_Frames;
      end;
   end Synchronize;

   procedure Adopt_Indexed_Data
     (Container  : in out Store;
      Object     : Image_Object_Access;
      Format     : Natural;
      Row_Stride : Natural;
      Data       : in out Terminal.App.Render_Model.Image_Data_Access)
   is
      Previous_Data : Terminal.App.Render_Model.Image_Data_Access;
      Previous_Format : Natural;
      Previous_Length : Natural;
      Previous_Stride : Natural;
   begin
      if Data = null then
         raise Constraint_Error with "cannot adopt null indexed image data";
      elsif not Is_Owned (Container, Object) then
         raise Program_Error with "image object is not owned by this store";
      elsif Owns_Data (Object, Data) then
         raise Program_Error with "indexed image data aliases owned storage";
      end if;
      if Format not in 8 | 16 then
         raise Constraint_Error with "indexed image format must be 8 or 16";
      end if;
      Validate_Pixel_Data
        (Format, Object.Pixel_Width, Object.Pixel_Height,
         Row_Stride, Data'Length);
      Previous_Data := Object.Indexed_Bytes;
      Previous_Format := Object.Indexed_Format;
      Previous_Length := Object.Indexed_Length;
      Previous_Stride := Object.Indexed_Row_Stride_Bytes;
      Object.Indexed_Bytes := Data;
      Object.Indexed_Format := Format;
      Object.Indexed_Length := Data'Length;
      Object.Indexed_Row_Stride_Bytes := Row_Stride;
      begin
         Synchronize (Container, Object);
      exception
         when others =>
            Object.Indexed_Bytes := Previous_Data;
            Object.Indexed_Format := Previous_Format;
            Object.Indexed_Length := Previous_Length;
            Object.Indexed_Row_Stride_Bytes := Previous_Stride;
            raise;
      end;
      Data := null;
      if Previous_Data /= null then
         Free_Image_Data (Previous_Data);
      end if;
   end Adopt_Indexed_Data;

   procedure Replace_Root_RGBA
     (Container : in out Store;
      Object    : Image_Object_Access;
      Data      : in out Terminal.App.Render_Model.Image_Data_Access;
      Preserve_Indexed : Boolean := False)
   is
      Previous_Data : Terminal.App.Render_Model.Image_Data_Access;
      Previous_Indexed : Terminal.App.Render_Model.Image_Data_Access;
      Previous_Format : Natural;
      Previous_Length : Natural;
      Previous_Stride : Natural;
      Previous_Indexed_Format : Natural;
      Previous_Indexed_Length : Natural;
      Previous_Indexed_Stride : Natural;
   begin
      if Data = null then
         raise Constraint_Error with "cannot install null RGBA image data";
      elsif not Is_Owned (Container, Object) then
         raise Program_Error with "image object is not owned by this store";
      elsif Owns_Data (Object, Data) then
         raise Program_Error with "RGBA image data aliases owned storage";
      elsif Object.Pixel_Width > Natural'Last / 4 then
         raise Constraint_Error with "RGBA row stride overflows";
      end if;
      Validate_Pixel_Data
        (32, Object.Pixel_Width, Object.Pixel_Height,
         Object.Pixel_Width * 4, Data'Length);

      Previous_Data := Object.Bytes;
      Previous_Indexed := Object.Indexed_Bytes;
      Previous_Format := Object.Raw_Format;
      Previous_Length := Object.Decoded_Length;
      Previous_Stride := Object.Decoded_Row_Stride_Bytes;
      Previous_Indexed_Format := Object.Indexed_Format;
      Previous_Indexed_Length := Object.Indexed_Length;
      Previous_Indexed_Stride := Object.Indexed_Row_Stride_Bytes;
      Object.Bytes := Data;
      Object.Raw_Format := 32;
      Object.Decoded_Length := Data'Length;
      Object.Decoded_Row_Stride_Bytes := Object.Pixel_Width * 4;
      if not Preserve_Indexed then
         Object.Indexed_Format := 0;
         Object.Indexed_Length := 0;
         Object.Indexed_Row_Stride_Bytes := 0;
         Object.Indexed_Bytes := null;
      end if;
      begin
         Synchronize (Container, Object);
      exception
         when others =>
            Object.Bytes := Previous_Data;
            Object.Raw_Format := Previous_Format;
            Object.Decoded_Length := Previous_Length;
            Object.Decoded_Row_Stride_Bytes := Previous_Stride;
            Object.Indexed_Format := Previous_Indexed_Format;
            Object.Indexed_Length := Previous_Indexed_Length;
            Object.Indexed_Row_Stride_Bytes := Previous_Indexed_Stride;
            Object.Indexed_Bytes := Previous_Indexed;
            raise;
      end;
      Data := null;
      if Previous_Data /= null then
         Free_Image_Data (Previous_Data);
      end if;
      if Previous_Indexed /= null and then not Preserve_Indexed then
         Free_Image_Data (Previous_Indexed);
      end if;
   end Replace_Root_RGBA;

   procedure Append_Frame
     (Container : in out Store;
      Object    : Image_Object_Access;
      Frame     : in out Image_Frame_Access)
   is
      Tail : Image_Frame_Access;
   begin
      if Frame = null then
         raise Constraint_Error with "cannot append a null image frame";
      elsif not Is_Owned (Container, Object) then
         raise Program_Error with "image object is not owned by this store";
      elsif Frame.Next /= null then
         raise Program_Error with "image frame is already linked";
      elsif Frame.Bytes = null then
         raise Constraint_Error with "cannot append a frame without data";
      elsif Frame.Length /= Frame.Bytes'Length then
         raise Constraint_Error with "image frame length does not match data";
      elsif Owns_Data (Object, Frame.Bytes) then
         raise Program_Error with "image frame aliases owned storage";
      elsif Object.Frame_Count = Positive'Last then
         raise Storage_Error with "image frame count overflow";
      elsif Frame.Number /= Object.Frame_Count + 1 then
         raise Constraint_Error with "image frame numbers must be contiguous";
      elsif Frame.Length > Natural'Last - Object.Frame_Bytes then
         raise Storage_Error with "image frame byte count overflow";
      end if;

      Tail := Object.Frames;
      if Tail = null then
         Object.Frames := Frame;
         Object.Frames_Tail := Frame;
      else
         Tail := Object.Frames_Tail;
         Tail.Next := Frame;
         Object.Frames_Tail := Frame;
      end if;
      Object.Frame_Count := Object.Frame_Count + 1;
      Object.Frame_Bytes := Object.Frame_Bytes + Frame.Length;
      begin
         Synchronize (Container, Object);
      exception
         when others =>
            Object.Frame_Count := Object.Frame_Count - 1;
            Object.Frame_Bytes := Object.Frame_Bytes - Frame.Length;
            if Tail = null then
               Object.Frames := null;
               Object.Frames_Tail := null;
            else
               Tail.Next := null;
               Object.Frames_Tail := Tail;
            end if;
            raise;
      end;
      Frame := null;
   end Append_Frame;

   procedure Adopt_Frames
     (Container : in out Store;
      Object    : Image_Object_Access;
      Head      : in out Image_Frame_Access) is separate;

   procedure Replace_Frame_Data
     (Container : in out Store;
      Object    : Image_Object_Access;
      Number    : Positive;
      Data      : in out Terminal.App.Render_Model.Image_Data_Access)
   is
      Frame : constant Image_Frame_Access := Find_Frame (Object, Number);
      Previous : Terminal.App.Render_Model.Image_Data_Access;
      Previous_Length : Natural;
      Current : Image_Frame_Access;
   begin
      if Data = null then
         raise Constraint_Error with "cannot install null frame data";
      elsif not Is_Owned (Container, Object) then
         raise Program_Error with "image object is not owned by this store";
      elsif Frame = null then
         raise Constraint_Error with "image frame does not exist";
      elsif Owns_Data (Object, Data) then
         raise Program_Error with "image frame data aliases owned storage";
      end if;
      Current := Object.Frames;
      while Current /= null loop
         if Current.Bytes = Data then
            raise Program_Error with "image frame data aliases owned storage";
         end if;
         Current := Current.Next;
      end loop;
      Previous := Frame.Bytes;
      Previous_Length := Frame.Length;
      if Data'Length > Previous_Length
        and then Data'Length - Previous_Length >
          Natural'Last - Object.Frame_Bytes
      then
         raise Storage_Error with "image frame byte count overflow";
      end if;
      Frame.Bytes := Data;
      Frame.Length := Data'Length;
      Object.Frame_Bytes := Object.Frame_Bytes - Previous_Length;
      Object.Frame_Bytes := Object.Frame_Bytes + Data'Length;
      begin
         Synchronize (Container, Object);
      exception
         when others =>
            Frame.Bytes := Previous;
            Frame.Length := Previous_Length;
            Object.Frame_Bytes := Object.Frame_Bytes - Data'Length;
            Object.Frame_Bytes := Object.Frame_Bytes + Previous_Length;
            raise;
      end;
      Data := null;
      Free_Image_Data (Previous);
   end Replace_Frame_Data;

   procedure Clear_Frames
     (Container : in out Store;
      Object    : Image_Object_Access)
   is
      Previous : Image_Frame_Access;
   begin
      if not Is_Owned (Container, Object) then
         raise Program_Error with "image object is not owned by this store";
      end if;
      Previous := Object.Frames;
      Object.Frames := null;
      Object.Frames_Tail := null;
      Object.Frame_Count := 1;
      Object.Frame_Bytes := 0;
      Synchronize (Container, Object);
      Release_Frame_List (Previous);
   end Clear_Frames;

   procedure Adopt_Theme_Operations
     (Container : in out Store;
      Object    : Image_Object_Access;
      Head      : in out Theme_Operation_Access) is separate;

   procedure Append_Theme_Operation
     (Container : in out Store;
      Object    : Image_Object_Access;
      Operation : in out Theme_Operation_Access) is separate;

   procedure Clear_Theme_Operations
     (Container : in out Store;
      Object    : Image_Object_Access)
   is
      Previous : Theme_Operation_Access;
   begin
      if not Is_Owned (Container, Object) then
         raise Program_Error with "image object is not owned by this store";
      end if;
      Previous := Object.Theme_Operations;
      Object.Theme_Operations := null;
      Object.Theme_Operations_Tail := null;
      Object.Theme_Operation_Count := 0;
      Object.Theme_Operation_Bytes := 0;
      Object.Theme_Addresses.Clear;
      Synchronize (Container, Object);
      Release_Theme_Operation_List (Previous);
   end Clear_Theme_Operations;

   procedure Archive_Root_Theme_Operations
     (Container      : in out Store;
      Object         : Image_Object_Access;
      Max_Operations : Positive) is separate;

   procedure Install_Root
     (Container        : in out Store;
      Object           : Image_Object_Access;
      Stream_ID        : Terminal.Core.Graphics_Stream_ID;
      ID               : Terminal.Core.Graphics_ID;
      Number           : Terminal.Core.Graphics_ID;
      Protocol         : Terminal.App.Render_Model.Image_Protocol;
      Raw_Format       : Natural;
      Pixel_Width      : Natural;
      Pixel_Height     : Natural;
      Decoded_Length   : Natural;
      Row_Stride       : Natural;
      Usage_Hint       : Natural;
      Data             : in out Terminal.App.Render_Model.Image_Data_Access)
   is separate;

   procedure Link_New
     (Container : in out Store;
      Object    : Image_Object_Access) is
   begin
      if Object = null then
         raise Constraint_Error with "cannot link a null image object";
      end if;
      if Object.Owner /= System.Null_Address then
         raise Program_Error with "image object is already owned";
      elsif Owned_Bytes (Object.all) /= 0
        or else Object.Frames /= null
        or else Object.Theme_Operations /= null
      then
         raise Program_Error with "new image object must not own data";
      elsif Container.Objects = Natural'Last then
         raise Storage_Error with "image object count overflow";
      end if;
      declare
         Accounted_Bytes : constant Natural := Owned_Bytes (Object.all);
         Accounted_Frames : constant Natural :=
           Owned_Animation_Frames (Object.all);
         New_Bytes : constant Natural :=
           Checked_Total (Container.Bytes, Accounted_Bytes);
         New_Frames : constant Natural :=
           Checked_Total
             (Container.Animation_Frames, Accounted_Frames);
      begin
         Object.Counted := True;
         Object.Replaces := null;
         Object.Owner := Container'Address;
         Object.Accounted_Bytes := Accounted_Bytes;
         Object.Accounted_Frames := Accounted_Frames;
         Container.Bytes := New_Bytes;
         Container.Animation_Frames := New_Frames;
         Object.Next := Container.Head;
         Container.Head := Object;
         Container.Objects := Container.Objects + 1;
      end;
   end Link_New;

   procedure Link_Replacement
     (Container : in out Store;
      Object    : Image_Object_Access;
      Replaced  : Image_Object_Access) is
   begin
      if Object = null then
         raise Constraint_Error with "cannot link a null image object";
      end if;
      if Object.Owner /= System.Null_Address then
         raise Program_Error with "image object is already owned";
      elsif Owned_Bytes (Object.all) /= 0
        or else Object.Frames /= null
        or else Object.Theme_Operations /= null
      then
         raise Program_Error with "replacement image object must not own data";
      elsif Replaced = null
        or else not Is_Owned (Container, Replaced)
        or else not Replaced.Counted
      then
         raise Program_Error with "replacement target is not committed";
      end if;
      declare
         Current : Image_Object_Access := Container.Head;
      begin
         while Current /= null loop
            if not Current.Counted and then Current.Replaces = Replaced then
               raise Program_Error with "replacement is already pending";
            end if;
            Current := Current.Next;
         end loop;
      end;
      declare
         Accounted_Bytes : constant Natural := Owned_Bytes (Object.all);
         Accounted_Frames : constant Natural :=
           Owned_Animation_Frames (Object.all);
         New_Bytes : constant Natural :=
           Checked_Total (Container.Bytes, Accounted_Bytes);
         New_Frames : constant Natural :=
           Checked_Total
             (Container.Animation_Frames, Accounted_Frames);
      begin
         Object.Counted := False;
         Object.Replaces := Replaced;
         Object.Owner := Container'Address;
         Object.Accounted_Bytes := Accounted_Bytes;
         Object.Accounted_Frames := Accounted_Frames;
         Container.Bytes := New_Bytes;
         Container.Animation_Frames := New_Frames;
         Object.Next := Container.Head;
         Container.Head := Object;
      end;
   end Link_Replacement;

   procedure Delete
     (Container : in out Store;
      Object    : in out Image_Object_Access;
      Counted   : Boolean)
   is
      Previous : Image_Object_Access := null;
      Current : Image_Object_Access := Container.Head;
   begin
      if Object = null then
         return;
      end if;
      while Current /= null and then Current /= Object loop
         Previous := Current;
         Current := Current.Next;
      end loop;
      if Current = null then
         raise Program_Error with "image object is not owned by this store";
      end if;
      if Counted and then not Current.Counted then
         raise Program_Error with "replacement object is not committed";
      elsif Counted and then Current.Counted then
         declare
            Candidate : Image_Object_Access := Container.Head;
         begin
            while Candidate /= null loop
               if not Candidate.Counted
                 and then Candidate.Replaces = Current
               then
                  raise Program_Error with
                    "cannot delete an object with a pending replacement";
               end if;
               Candidate := Candidate.Next;
            end loop;
         end;
      elsif not Counted and then Current.Counted then
         declare
            Replacement : Image_Object_Access := Container.Head;
         begin
            while Replacement /= null loop
               exit when not Replacement.Counted
                 and then Replacement.Replaces = Current;
               Replacement := Replacement.Next;
            end loop;
            if Replacement = null then
               raise Program_Error with "replacement object is missing";
            end if;
            Replacement.Counted := True;
            Replacement.Replaces := null;
         end;
      end if;
      if Previous = null then
         Container.Head := Current.Next;
      else
         Previous.Next := Current.Next;
      end if;
      if Counted then
         Container.Objects := Container.Objects - 1;
      end if;
      Container.Bytes := Container.Bytes - Current.Accounted_Bytes;
      Container.Animation_Frames :=
        Container.Animation_Frames - Current.Accounted_Frames;
      Release_Contents (Current.all);
      Free_Image_Object (Current);
      Object := null;
   end Delete;

   procedure Delete_Object
     (Container : in out Store;
      Object    : in out Image_Object_Access) is
   begin
      Delete (Container, Object, Counted => True);
   end Delete_Object;

   procedure Delete_Replacement
     (Container : in out Store;
      Object    : in out Image_Object_Access) is
   begin
      Delete (Container, Object, Counted => False);
   end Delete_Replacement;

   procedure Release_All (Container : in out Store) is
      Current : Image_Object_Access := Container.Head;
   begin
      while Current /= null loop
         declare
            Next : constant Image_Object_Access := Current.Next;
         begin
            Release_Contents (Current.all);
            Free_Image_Object (Current);
            Current := Next;
         end;
      end loop;
      Container.Head := null;
      Container.Objects := 0;
      Container.Bytes := 0;
      Container.Animation_Frames := 0;
   end Release_All;

   overriding procedure Finalize (Container : in out Store) is
   begin
      Release_All (Container);
   end Finalize;

   function Allocate_Storage_Order
     (Container : in out Store) return Interfaces.Unsigned_64
   is
      Result : constant Interfaces.Unsigned_64 := Container.Next_Storage_Order;
   begin
      Container.Next_Storage_Order := Container.Next_Storage_Order + 1;
      if Container.Next_Storage_Order = 0 then
         Container.Next_Storage_Order := 1;
      end if;
      return Result;
   end Allocate_Storage_Order;

   function Allocate_Content_Serial
     (Container : in out Store) return Interfaces.Unsigned_64
   is
      Result : constant Interfaces.Unsigned_64 := Container.Next_Content_Serial;
   begin
      Container.Next_Content_Serial := Container.Next_Content_Serial + 1;
      if Container.Next_Content_Serial = 0 then
         Container.Next_Content_Serial := 1;
      end if;
      return Result;
   end Allocate_Content_Serial;

   procedure Touch
     (Container : in out Store;
      Object    : Image_Object_Access) is
   begin
      if Object /= null then
         Synchronize (Container, Object);
         Mark_Content_Changed (Container, Object);
      end if;
   end Touch;

   procedure Mark_Content_Changed
     (Container : in out Store;
      Object    : Image_Object_Access) is
   begin
      if Object = null or else not Is_Owned (Container, Object) then
         raise Program_Error with "image object is not owned by this store";
      end if;
      Object.Content_Serial := Allocate_Content_Serial (Container);
   end Mark_Content_Changed;

   function Allocation_Allowed
     (Control : in out Allocation_Control) return Boolean is
   begin
      if Control.Remaining_Attempts = 0 then
         return True;
      end if;
      Control.Remaining_Attempts := Control.Remaining_Attempts - 1;
      return Control.Remaining_Attempts /= 0;
   end Allocation_Allowed;

end Terminal.App.Image_Store;
