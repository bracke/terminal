separate (Terminal.App.Renderer.Theme_State)
function Prepare_Theme_Baseline
  (Object          : Image_Object_Access;
   Head            : out Theme_Operation_Access;
   Tail            : out Theme_Operation_Access;
   Required_Bytes  : out Natural;
   Required_Count  : out Natural) return Boolean
is
   Root_Length : Natural;
   Root_Format : Natural;
   Root_Stride : Natural;
   Root_Is_Indexed : Boolean := False;
   Position : Frames.Cursor;
   Borrow : Terminal.App.Image_Store.Data_Borrow;

   procedure Reset_Preparation is
   begin
      Release_Theme_Operation_List (Head);
      Tail := null;
      Required_Bytes := 0;
      Required_Count := 0;
   end Reset_Preparation;

   procedure Add_Baseline
     (Target : Positive;
      Format : Natural;
      Stride : Natural;
      Source : Terminal.Common.Bytes.Byte_Array;
      Length : Natural)
   is
      Op : Theme_Operation_Access := null;
      Copy : Terminal.App.Owned_Image_Data.Owner;
      Description : Terminal.App.Image_Store.Theme_Operation_Descriptor :=
        (New_Frame             => True,
         Target_Frame          => Target,
         Raw_Format            => Format,
         Data_Width            => Object.Pixel_Width,
         Data_Height           => Object.Pixel_Height,
         Data_Row_Stride_Bytes => Stride,
         Composition_Mode      => 1,
         others                => <>);
   begin
      Terminal.App.Owned_Image_Data.Allocate (Copy, Length);
      Terminal.App.Owned_Image_Data.Copy
        (Copy, Source (Source'First .. Source'First + Length - 1));
      Themes.Create
        (Description, Copy, Op);
      Themes.Append_Unowned
        (Head, Tail, Op);
   exception
      when others =>
         Themes.Release_Unowned (Op);
         raise;
   end Add_Baseline;

   procedure Add_Stored_Baseline is
      Op : Theme_Operation_Access := null;
      Copy : Terminal.App.Owned_Image_Data.Owner;
      Description : Terminal.App.Image_Store.Theme_Operation_Descriptor :=
        (New_Frame             => True,
         Target_Frame          => 1,
         Raw_Format            => Root_Format,
         Data_Width            => Object.Pixel_Width,
         Data_Height           => Object.Pixel_Height,
         Data_Row_Stride_Bytes => Root_Stride,
         Composition_Mode      => 1,
         others                => <>);
   begin
      Terminal.App.Owned_Image_Data.Allocate (Copy, Root_Length);
      declare
         procedure Copy_Root
           (Bytes : in out Terminal.Common.Bytes.Byte_Array) is
         begin
            if Root_Is_Indexed then
               Terminal.App.Image_Store.Copy_Indexed_Data (Borrow, Bytes);
            else
               Terminal.App.Image_Store.Copy_Root_Data (Borrow, Bytes);
            end if;
         end Copy_Root;
      begin
         Terminal.App.Owned_Image_Data.Modify (Copy, Copy_Root'Access);
      end;
      Themes.Create (Description, Copy, Op);
      Themes.Append_Unowned (Head, Tail, Op);
   exception
      when others =>
         Themes.Release_Unowned (Op);
         raise;
   end Add_Stored_Baseline;
begin
   Head := null;
   Tail := null;
   Required_Bytes := 0;
   Required_Count := 0;
   if Object = null then
      return False;
   elsif Themes.Count (Object) > 0 then
      return True;
   elsif not Image_Objects.Has_Stored_Root (Object) then
      return False;
   end if;

   Terminal.App.Image_Store.Borrow (Borrow, Object);
   if Terminal.App.Image_Store.Borrowed_Indexed_Length (Borrow) > 0
     and then Terminal.App.Image_Store.Indexed_Data_Format (Object) in 8 | 16
   then
      Root_Is_Indexed := True;
      Root_Length := Terminal.App.Image_Store.Borrowed_Indexed_Length (Borrow);
      Root_Format := Terminal.App.Image_Store.Indexed_Data_Format (Object);
      Root_Stride := Terminal.App.Image_Store.Indexed_Row_Stride (Object);
   else
      Root_Length := Terminal.App.Image_Store.Borrowed_Root_Length (Borrow);
      Root_Format := Object.Raw_Format;
      Root_Stride := Object.Decoded_Row_Stride_Bytes;
   end if;
   if Root_Length = 0 then
      return False;
   end if;
   Required_Bytes := Root_Length;
   Required_Count := 1;
   Position := Frames.First (Borrow);
   Frames.Next (Borrow, Position);
   while Frames.Has_Element (Position) loop
      declare
         Info : constant Frames.Frame_Descriptor :=
           Frames.Descriptor (Borrow, Position);
         Found : Boolean;
         procedure Note_Source
           (Source : Terminal.Common.Bytes.Byte_Array) is
            pragma Unreferenced (Source);
         begin
            null;
         end Note_Source;
      begin
         Found := Frames.Visit_Data (Borrow, Position, Note_Source'Access);
         if not Found or else Info.Length > Natural'Last - Required_Bytes
         then
            Reset_Preparation;
            return False;
         end if;
         Required_Bytes := Required_Bytes + Info.Length;
         Required_Count := Required_Count + 1;
      end;
      Frames.Next (Borrow, Position);
   end loop;
   Add_Stored_Baseline;
   Position := Frames.First (Borrow);
   Frames.Next (Borrow, Position);
   while Frames.Has_Element (Position) loop
      declare
         Info : constant Frames.Frame_Descriptor :=
           Frames.Descriptor (Borrow, Position);
         Added : Boolean;
         procedure Add_Frame
           (Source : Terminal.Common.Bytes.Byte_Array) is
         begin
            Add_Baseline
              (Info.Number,
               32,
               Object.Pixel_Width * 4,
               Source,
               Info.Length);
         end Add_Frame;
      begin
         Added := Frames.Visit_Data (Borrow, Position, Add_Frame'Access);
         if not Added then
            Reset_Preparation;
            return False;
         end if;
      end;
      Frames.Next (Borrow, Position);
   end loop;

   Terminal.App.Image_Store.Release (Borrow);
   return True;
exception
   when Storage_Error =>
      Reset_Preparation;
      raise;
   when Constraint_Error =>
      Reset_Preparation;
      return False;
end Prepare_Theme_Baseline;
