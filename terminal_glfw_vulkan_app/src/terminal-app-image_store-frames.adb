with Ada.Unchecked_Deallocation;
with Terminal.App.Image_Store.Data_Borrows;
with Terminal.App.Image_Upload_Layout;
with Terminal.App.Owned_Image_Data;
with System;

package body Terminal.App.Image_Store.Frames is
   use type Interfaces.Unsigned_64;
   use type Terminal.App.Render_Model.Image_Data_View;
   procedure Free_Index is new Ada.Unchecked_Deallocation
     (Image_Frame_Index_Array, Image_Frame_Index_Access);
   procedure Create
     (Number     : Positive;
      Gap_MS     : Integer;
      Usage_Hint : Natural;
      Data       : in out Terminal.App.Owned_Image_Data.Owner;
      Frame      : out Image_Frame_Access) is
   begin
      Frame := null;
      if Terminal.App.Owned_Image_Data.Is_Empty (Data) then
         raise Constraint_Error with "cannot create a frame without data";
      end if;
      Frame := new Image_Frame'
        (Number => Number, Gap_MS => Gap_MS, Usage_Hint => Usage_Hint,
         Bytes => <>,
         Length => Terminal.App.Owned_Image_Data.Length (Data), Next => null);
      Terminal.App.Owned_Image_Data.Move (Data, Frame.Bytes);
   end Create;

   procedure Append_Unowned
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
   end Append_Unowned;

   procedure Release_Unowned (Head : in out Image_Frame_Access) is
   begin
      Release_Frame_List (Head);
   end Release_Unowned;

   procedure Validate (Borrow : Data_Borrow; Position : Cursor) is
   begin
      if Borrow.Hold.Object = null then
         raise Program_Error with "frame traversal requires an active borrow";
      elsif Position.Owner /= Borrow.Hold.Object then
         raise Program_Error with "frame cursor belongs to a different borrow";
      elsif Position.Token = 0 or else Position.Token /= Borrow.Hold.Token then
         raise Program_Error with "frame cursor borrow has expired";
      elsif not Position.Active then
         raise Constraint_Error with "frame cursor has no element";
      elsif not Position.Is_Root and then Position.Current = null then
         raise Program_Error with "frame cursor state is inconsistent";
      end if;
   end Validate;

   function First (Borrow : Data_Borrow) return Cursor is
   begin
      if Borrow.Hold.Object = null then
         raise Program_Error with "frame traversal requires an active borrow";
      end if;
      return
        (Owner   => Borrow.Hold.Object,
         Current => null,
         Is_Root => True,
         Active  => True,
         Token   => Borrow.Hold.Token);
   end First;

   function Has_Element (Position : Cursor) return Boolean is
     (Position.Active);

   procedure Next (Borrow : Data_Borrow; Position : in out Cursor) is
   begin
      Validate (Borrow, Position);
      if Position.Is_Root then
         Position.Is_Root := False;
         Position.Current := Borrow.Hold.Object.State.Frames;
      else
         Position.Current := Position.Current.Next;
      end if;
      Position.Active := Position.Current /= null;
   end Next;

   function Descriptor
     (Borrow   : Data_Borrow;
      Position : Cursor) return Frame_Descriptor is
   begin
      Validate (Borrow, Position);
      if Position.Is_Root then
         return
           (Number     => 1,
            Gap_MS     => Borrow.Hold.Object.State.Root_Gap_MS,
            Usage_Hint => Borrow.Hold.Object.State.Usage_Hint,
            Length     => Root_Data_Length (Borrow.Hold.Object));
      else
         return
           (Number     => Position.Current.Number,
            Gap_MS     => Position.Current.Gap_MS,
            Usage_Hint => Position.Current.Usage_Hint,
            Length     => Position.Current.Length);
      end if;
   end Descriptor;

   function Visit_Data
     (Borrow   : Data_Borrow;
      Position : Cursor;
      Process  : not null access procedure
        (Data : Terminal.Common.Bytes.Byte_Array)) return Boolean
   is
      View : Terminal.App.Render_Model.Image_Data_View;
   begin
      Validate (Borrow, Position);
      View :=
        (if Position.Is_Root
         then Root_Data (Borrow.Hold.Object)
         else
           Terminal.App.Owned_Image_Data.Unsafe_View
             (Position.Current.Bytes));
      if View /= null then
         Process (View.all);
         return True;
      end if;
      return False;
   end Visit_Data;

   function Count (Object : Image_Object_Access) return Natural is
     (if Object = null then 0 else Object.State.Frame_Count);

   function Find
     (Object : Image_Object_Access;
      Number : Positive) return Image_Frame_Access is
   begin
      if Object = null
        or else Number = 1
        or else Number > Object.State.Frame_Count
        or else Object.State.Frame_Index = null
        or else Number > Object.State.Frame_Index'Last
      then
         return null;
      end if;
      return Object.State.Frame_Index (Number);
   end Find;

   function Descriptor
     (Object : Image_Object_Access;
      Number : Positive) return Frame_Descriptor
   is
      Frame : constant Image_Frame_Access := Find (Object, Number);
   begin
      if Object = null or else Number > Object.State.Frame_Count then
         raise Constraint_Error with "image frame does not exist";
      elsif Number = 1 then
         return
           (Number     => 1,
            Gap_MS     => Object.State.Root_Gap_MS,
            Usage_Hint => Object.State.Usage_Hint,
            Length     => Root_Data_Length (Object));
      elsif Frame = null then
         raise Program_Error with "image frame list is inconsistent";
      end if;
      return
        (Number     => Frame.Number,
         Gap_MS     => Frame.Gap_MS,
         Usage_Hint => Frame.Usage_Hint,
         Length     => Frame.Length);
   end Descriptor;

   function Exists
     (Object : Image_Object_Access;
      Number : Natural) return Boolean is
     --  Append and Adopt enforce contiguous numbering, and frames are cleared
     --  as a group.  Frame_Count is therefore the authoritative O(1) range.
     (Object /= null and then Number in 1 .. Object.State.Frame_Count);

   function Gap
     (Object : Image_Object_Access;
      Number : Positive) return Integer
   is
      Frame : constant Image_Frame_Access := Find (Object, Number);
   begin
      if Object = null then
         return 0;
      elsif Number = 1 then
         return Object.State.Root_Gap_MS;
      else
         return (if Frame = null then 0 else Frame.Gap_MS);
      end if;
   end Gap;

   function Set_Gap
     (Container : in out Store;
      Object    : Image_Object_Access;
      Number    : Positive;
      Gap       : Integer) return Boolean
   is
      Frame : constant Image_Frame_Access := Find (Object, Number);
   begin
      if not Is_Owned (Container, Object) then
         return False;
      elsif Number = 1 then
         Object.State.Root_Gap_MS := Gap;
         return True;
      elsif Frame /= null then
         Frame.Gap_MS := Gap;
         return True;
      end if;
      return False;
   end Set_Gap;

   function Set_Usage_Hint
     (Container : in out Store;
      Object    : Image_Object_Access;
      Number    : Positive;
      Value     : Natural) return Boolean
   is
      Frame : constant Image_Frame_Access := Find (Object, Number);
   begin
      if not Is_Owned (Container, Object) then
         return False;
      elsif Number = 1 then
         Object.State.Usage_Hint := Value;
         return True;
      elsif Frame /= null then
         Frame.Usage_Hint := Value;
         return True;
      end if;
      return False;
   end Set_Usage_Hint;

   procedure Copy_To_RGBA
     (Object : Image_Object_Access;
      Number : Positive;
      Target : in out Terminal.Common.Bytes.Byte_Array;
      Valid  : out Boolean)
   is
      Borrow : Data_Borrow;
      Source : Terminal.App.Render_Model.Image_Data_View;
      Pixels : Natural;
      Source_Stride : Natural := 0;
      Required_Source_Bytes : Natural := 0;
   begin
      Valid := False;
      if Object = null then
         return;
      end if;
      Terminal.App.Image_Store.Borrow (Borrow, Object);
      Source := Data_Borrows.Frame_Data (Borrow, Number);
      if Source = null
        or else Object.State.Pixel_Width = 0
        or else Object.State.Pixel_Height = 0
        or else Object.State.Pixel_Width > Natural'Last / Object.State.Pixel_Height
      then
         return;
      end if;
      Pixels := Object.State.Pixel_Width * Object.State.Pixel_Height;
      if Pixels > Natural'Last / 4 or else Target'Length /= Pixels * 4 then
         return;
      end if;
      if Number /= 1 then
         if Source'Length < Target'Length then
            return;
         end if;
         Target := Source (Source'First .. Source'First + Target'Length - 1);
      elsif Object.State.Raw_Format in 24 | 32 then
         declare
            BPP : constant Positive := (if Object.State.Raw_Format = 32 then 4 else 3);
         begin
            Source_Stride := Object.State.Decoded_Row_Stride_Bytes;
            Required_Source_Bytes :=
              Terminal.App.Image_Upload_Layout.Required_Source_Bytes
                (Width                  => Object.State.Pixel_Width,
                 Height                 => Object.State.Pixel_Height,
                 Source_Bytes_Per_Pixel => BPP,
                 Row_Stride_Bytes       => Source_Stride,
                 Maximum_Bytes          => Natural'Last);
            if Required_Source_Bytes = 0
              or else Source'Length < Required_Source_Bytes
            then
               return;
            end if;
            for Row in 0 .. Object.State.Pixel_Height - 1 loop
               for Col in 0 .. Object.State.Pixel_Width - 1 loop
                  declare
                     Source_First : constant Positive :=
                       Source'First + Row * Source_Stride + Col * BPP;
                     Target_First : constant Positive :=
                       Target'First + (Row * Object.State.Pixel_Width + Col) * 4;
                  begin
                     Target (Target_First) := Source (Source_First);
                     Target (Target_First + 1) := Source (Source_First + 1);
                     Target (Target_First + 2) := Source (Source_First + 2);
                     Target (Target_First + 3) :=
                       (if BPP = 4 then Source (Source_First + 3) else 255);
                  end;
               end loop;
            end loop;
         end;
      else
         return;
      end if;
      Valid := True;
   end Copy_To_RGBA;

   procedure Append
     (Container : in out Store;
      Object    : Image_Object_Access;
      Frame     : in out Image_Frame_Access)
   is
      Tail : Image_Frame_Access;
      Previous_Index : Image_Frame_Index_Access := null;
      Replacement_Index : Image_Frame_Index_Access := null;
      Previous_Capacity : Natural := 0;
      Required_Capacity : Positive := 1;
   begin
      if Frame = null then
         raise Constraint_Error with "cannot append a null image frame";
      elsif not Is_Owned (Container, Object) then
         raise Program_Error with "image object is not owned by this store";
      elsif Frame.Next /= null then
         raise Program_Error with "image frame is already linked";
      elsif Terminal.App.Owned_Image_Data.Is_Empty (Frame.Bytes) then
         raise Constraint_Error with "cannot append a frame without data";
      elsif Frame.Length /= Terminal.App.Owned_Image_Data.Length (Frame.Bytes)
      then
         raise Constraint_Error with "image frame length does not match data";
      elsif Owns_Data_View
        (Object, Terminal.App.Owned_Image_Data.Unsafe_View (Frame.Bytes))
      then
         raise Program_Error with "image frame aliases owned storage";
      elsif Object.State.Frame_Count = Positive'Last then
         raise Storage_Error with "image frame count overflow";
      elsif Frame.Number /= Object.State.Frame_Count + 1 then
         raise Constraint_Error with "image frame numbers must be contiguous";
      elsif Frame.Length > Natural'Last - Object.State.Frame_Bytes then
         raise Storage_Error with "image frame byte count overflow";
      end if;
      Assert_Not_Borrowed (Object.all);
      Previous_Index := Object.State.Frame_Index;
      Previous_Capacity := Object.State.Frame_Index_Capacity;
      Required_Capacity := Frame.Number;
      if Required_Capacity > Object.State.Frame_Index_Capacity then
         declare
            New_Capacity : Positive := Positive'Max (2, Required_Capacity);
         begin
            if Object.State.Frame_Index_Capacity > 0
              and then Object.State.Frame_Index_Capacity <= Positive'Last / 2
            then
               New_Capacity := Positive'Max
                 (Required_Capacity, Object.State.Frame_Index_Capacity * 2);
            end if;
            Replacement_Index := new Image_Frame_Index_Array
              (1 .. New_Capacity);
            Replacement_Index.all := (others => null);
            if Previous_Index /= null then
               Replacement_Index (Previous_Index'Range) := Previous_Index.all;
            end if;
            Object.State.Frame_Index := Replacement_Index;
            Object.State.Frame_Index_Capacity := New_Capacity;
         end;
      end if;
      Object.State.Frame_Index (Frame.Number) := Frame;
      Tail := Object.State.Frames;
      if Tail = null then
         Object.State.Frames := Frame;
         Object.State.Frames_Tail := Frame;
      else
         Tail := Object.State.Frames_Tail;
         Tail.Next := Frame;
         Object.State.Frames_Tail := Frame;
      end if;
      Object.State.Frame_Count := Object.State.Frame_Count + 1;
      Object.State.Frame_Bytes := Object.State.Frame_Bytes + Frame.Length;
      begin
         Synchronize (Container, Object);
      exception
         when others =>
            Object.State.Frame_Index (Frame.Number) := null;
            if Replacement_Index /= null then
               Object.State.Frame_Index := Previous_Index;
               Object.State.Frame_Index_Capacity := Previous_Capacity;
               Free_Index (Replacement_Index);
            end if;
            Object.State.Frame_Count := Object.State.Frame_Count - 1;
            Object.State.Frame_Bytes := Object.State.Frame_Bytes - Frame.Length;
            if Tail = null then
               Object.State.Frames := null;
               Object.State.Frames_Tail := null;
            else
               Tail.Next := null;
               Object.State.Frames_Tail := Tail;
            end if;
            raise;
      end;
      if Replacement_Index /= null then
         Free_Index (Previous_Index);
      end if;
      Frame := null;
   end Append;

   procedure Adopt
     (Container : in out Store;
      Object    : Image_Object_Access;
      Head      : in out Image_Frame_Access)
   is
      Slow : Image_Frame_Access := Head;
      Fast : Image_Frame_Access := Head;
      Current : Image_Frame_Access := Head;
      Tail : Image_Frame_Access := null;
      Count : Natural := 0;
      Total_Bytes : Natural := 0;
      Seen : Address_Sets.Set;
      Previous_Index : Image_Frame_Index_Access := null;
      Previous_Capacity : Natural := 0;
      New_Index : Image_Frame_Index_Access := null;

      procedure Register
        (Data : Terminal.App.Render_Model.Image_Data_View)
      is
         Address : System.Address;
      begin
         if Data = null then
            return;
         end if;
         Address := Data.all'Address;
         if Seen.Contains (Address) then
            raise Program_Error with "image frames share owned storage";
         end if;
         Seen.Insert (Address);
      end Register;
   begin
      if not Is_Owned (Container, Object) then
         raise Program_Error with "image object is not owned by this store";
      elsif Object.State.Frames /= null then
         raise Program_Error with "image object already has animation frames";
      end if;
      Assert_Not_Borrowed (Object.all);
      Previous_Index := Object.State.Frame_Index;
      Previous_Capacity := Object.State.Frame_Index_Capacity;
      Register (Terminal.App.Owned_Image_Data.Unsafe_View (Object.Bytes));
      Register
        (Terminal.App.Owned_Image_Data.Unsafe_View (Object.Indexed_Bytes));
      declare
         Operation : Theme_Operation_Access := Object.State.Theme_Operations;
      begin
         while Operation /= null loop
            Register
              (Terminal.App.Owned_Image_Data.Unsafe_View (Operation.Bytes));
            Operation := Operation.Next;
         end loop;
      end;
      while Fast /= null and then Fast.Next /= null loop
         Slow := Slow.Next;
         Fast := Fast.Next.Next;
         if Slow = Fast then
            raise Program_Error with "image frame list is cyclic";
         end if;
      end loop;
      while Current /= null loop
         if Terminal.App.Owned_Image_Data.Is_Empty (Current.Bytes)
           or else Current.Length /=
             Terminal.App.Owned_Image_Data.Length (Current.Bytes)
         then
            raise Constraint_Error with "image frame length does not match data";
         end if;
         Register
           (Terminal.App.Owned_Image_Data.Unsafe_View (Current.Bytes));
         if Count >= Positive'Last - 1 then
            raise Storage_Error with "image frame accounting overflow";
         elsif Current.Number /= Count + 2 then
            raise Constraint_Error with "image frame numbers must be contiguous";
         elsif Current.Length > Natural'Last - Total_Bytes then
            raise Storage_Error with "image frame accounting overflow";
         end if;
         Count := Count + 1;
         Total_Bytes := Total_Bytes + Current.Length;
         Tail := Current;
         Current := Current.Next;
      end loop;
      New_Index := new Image_Frame_Index_Array (1 .. Positive (Count + 1));
      New_Index.all := (others => null);
      Current := Head;
      while Current /= null loop
         New_Index (Current.Number) := Current;
         Current := Current.Next;
      end loop;
      Object.State.Frames := Head;
      Object.State.Frames_Tail := Tail;
      Object.State.Frame_Index := New_Index;
      Object.State.Frame_Index_Capacity := New_Index'Length;
      Object.State.Frame_Count := Positive (Count + 1);
      Object.State.Frame_Bytes := Total_Bytes;
      begin
         Synchronize (Container, Object);
      exception
         when others =>
            Object.State.Frames := null;
            Object.State.Frames_Tail := null;
            Object.State.Frame_Index := Previous_Index;
            Object.State.Frame_Index_Capacity := Previous_Capacity;
            Object.State.Frame_Count := 1;
            Object.State.Frame_Bytes := 0;
            Free_Index (New_Index);
            raise;
      end;
      New_Index := null;
      Free_Index (Previous_Index);
      Head := null;
   end Adopt;

   procedure Replace_Data
     (Container : in out Store;
      Object    : Image_Object_Access;
      Number    : Positive;
      Data      : in out Terminal.App.Owned_Image_Data.Owner;
      Set_Gap   : Boolean := False;
      Gap_MS    : Integer := 0;
      Set_Usage : Boolean := False;
      Usage_Hint : Natural := 0)
   is
      Frame : constant Image_Frame_Access := Find (Object, Number);
      Previous : Terminal.App.Owned_Image_Data.Owner;
      Previous_Length : Natural;
      Previous_Gap : Integer;
      Previous_Usage : Natural;
   begin
      if Terminal.App.Owned_Image_Data.Is_Empty (Data) then
         raise Constraint_Error with "cannot install null frame data";
      elsif not Is_Owned (Container, Object) then
         raise Program_Error with "image object is not owned by this store";
      elsif Frame = null then
         raise Constraint_Error with "image frame does not exist";
      elsif Owns_Data_View
        (Object, Terminal.App.Owned_Image_Data.Unsafe_View (Data))
      then
         raise Program_Error with "image frame data aliases owned storage";
      end if;
      Assert_Not_Borrowed (Object.all);
      Previous_Length := Frame.Length;
      Previous_Gap := Frame.Gap_MS;
      Previous_Usage := Frame.Usage_Hint;
      if Terminal.App.Owned_Image_Data.Length (Data) > Previous_Length
        and then Terminal.App.Owned_Image_Data.Length (Data) - Previous_Length >
          Natural'Last - Object.State.Frame_Bytes
      then
         raise Storage_Error with "image frame byte count overflow";
      end if;
      Terminal.App.Owned_Image_Data.Move (Frame.Bytes, Previous);
      Terminal.App.Owned_Image_Data.Move (Data, Frame.Bytes);
      Frame.Length := Terminal.App.Owned_Image_Data.Length (Frame.Bytes);
      if Set_Gap then
         Frame.Gap_MS := Gap_MS;
      end if;
      if Set_Usage then
         Frame.Usage_Hint := Usage_Hint;
      end if;
      Object.State.Frame_Bytes := Object.State.Frame_Bytes - Previous_Length + Frame.Length;
      begin
         Synchronize (Container, Object);
      exception
         when others =>
            Terminal.App.Owned_Image_Data.Move (Frame.Bytes, Data);
            Terminal.App.Owned_Image_Data.Move (Previous, Frame.Bytes);
            Frame.Length := Previous_Length;
            Frame.Gap_MS := Previous_Gap;
            Frame.Usage_Hint := Previous_Usage;
            Object.State.Frame_Bytes :=
              Object.State.Frame_Bytes
              - Terminal.App.Owned_Image_Data.Length (Data)
              + Previous_Length;
            raise;
      end;
      Terminal.App.Owned_Image_Data.Release (Previous);
   end Replace_Data;

   procedure Clear
     (Container : in out Store;
      Object    : Image_Object_Access)
   is
      Previous : Image_Frame_Access;
      Previous_Tail : Image_Frame_Access;
      Previous_Count : Positive;
      Previous_Bytes : Natural;
   begin
      if not Is_Owned (Container, Object) then
         raise Program_Error with "image object is not owned by this store";
      end if;
      Assert_Not_Borrowed (Object.all);
      Previous := Object.State.Frames;
      Previous_Tail := Object.State.Frames_Tail;
      Previous_Count := Object.State.Frame_Count;
      Previous_Bytes := Object.State.Frame_Bytes;
      Object.State.Frames := null;
      Object.State.Frames_Tail := null;
      Object.State.Frame_Count := 1;
      Object.State.Frame_Bytes := 0;
      begin
         Synchronize (Container, Object);
      exception
         when others =>
            Object.State.Frames := Previous;
            Object.State.Frames_Tail := Previous_Tail;
            Object.State.Frame_Count := Previous_Count;
            Object.State.Frame_Bytes := Previous_Bytes;
            raise;
      end;
      if Object.State.Frame_Index /= null then
         for Number in 2 .. Previous_Count loop
            Object.State.Frame_Index (Number) := null;
         end loop;
      end if;
      Release_Unowned (Previous);
   end Clear;
end Terminal.App.Image_Store.Frames;
