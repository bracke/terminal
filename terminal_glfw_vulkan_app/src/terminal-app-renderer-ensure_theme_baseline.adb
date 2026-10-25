separate (Terminal.App.Renderer)
function Ensure_Theme_Baseline
  (R      : in out Renderer;
   Object : Image_Object_Access) return Boolean
is
   Required_Bytes : Natural := 0;
   Required_Count : Natural := 1;
   Root_Source : RM.Image_Data_View;
   Root_Length : Natural;
   Root_Format : Natural;
   Root_Stride : Natural;
   Frame : Image_Frame_Access;
   Head : Theme_Operation_Access := null;
   Tail : Theme_Operation_Access := null;

   procedure Add_Baseline
     (Target : Positive;
      Format : Natural;
      Stride : Natural;
      Source : RM.Image_Data_View;
      Length : Natural)
   is
      Op : Theme_Operation_Access := null;
      Copy : RM.Image_Data_Access := null;
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
      Copy := new Terminal.Common.Bytes.Byte_Array (1 .. Length);
      Copy.all := Source (Source'First .. Source'First + Length - 1);
      Terminal.App.Image_Store.Create_Theme_Operation
        (Description, Copy, Op);
      Terminal.App.Image_Store.Append_Unowned_Theme_Operation
        (Head, Tail, Op);
   exception
      when others =>
         Free_Image_Data (Copy);
         Terminal.App.Image_Store.Release_Unowned_Theme_Operations (Op);
         raise;
   end Add_Baseline;
begin
   if Object = null then
      return False;
   elsif Terminal.App.Image_Store.First_Theme_Operation (Object) /= null then
      return True;
   elsif Terminal.App.Image_Store.Root_Data (Object) = null then
      return False;
   end if;

   if Terminal.App.Image_Store.Indexed_Data (Object) /= null
     and then Terminal.App.Image_Store.Indexed_Data_Format (Object) in 8 | 16
   then
      Root_Source := Terminal.App.Image_Store.Indexed_Data (Object);
      Root_Length := Terminal.App.Image_Store.Indexed_Data_Length (Object);
      Root_Format := Terminal.App.Image_Store.Indexed_Data_Format (Object);
      Root_Stride := Terminal.App.Image_Store.Indexed_Row_Stride (Object);
   else
      Root_Source := Terminal.App.Image_Store.Root_Data (Object);
      Root_Length := Object.Decoded_Length;
      Root_Format := Object.Raw_Format;
      Root_Stride := Object.Decoded_Row_Stride_Bytes;
   end if;
   if Root_Source = null or else Root_Length = 0 then
      return False;
   end if;
   Required_Bytes := Root_Length;
   Frame := Terminal.App.Image_Store.First_Frame (Object);
   while Frame /= null loop
      if Frame.Bytes = null
        or else Frame.Length > Natural'Last - Required_Bytes
      then
         return False;
      end if;
      Required_Bytes := Required_Bytes + Frame.Length;
      Required_Count := Required_Count + 1;
      Frame := Terminal.App.Image_Store.Next_Frame (Frame);
   end loop;
   if not Reserve_Theme_Operation_Bytes
     (R, Object, Required_Bytes, Required_Count)
   then
      return False;
   end if;

   Add_Baseline (1, Root_Format, Root_Stride, Root_Source, Root_Length);
   Frame := Terminal.App.Image_Store.First_Frame (Object);
   while Frame /= null loop
      Add_Baseline
        (Frame.Number,
         32,
         Object.Pixel_Width * 4,
         Frame.Bytes,
         Frame.Length);
      Frame := Terminal.App.Image_Store.Next_Frame (Frame);
   end loop;

   Terminal.App.Image_Store.Adopt_Theme_Operations
     (R.Image_Objects, Object, Head);
   return True;
exception
   when Storage_Error =>
      Release_Theme_Operation_List (Head);
      raise;
   when Constraint_Error =>
      Release_Theme_Operation_List (Head);
      return False;
end Ensure_Theme_Baseline;
