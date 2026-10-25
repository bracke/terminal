separate (Terminal.App.Renderer)
function Prepare_Theme_Frame_Operation
  (R             : in out Renderer;
   Object        : Image_Object_Access;
   Header        : Terminal.App.Graphics.Graphics_Header;
   Data          : Terminal.App.Graphics.Graphics_Data_Preview;
   Target_Number : Positive;
   New_Frame     : Boolean;
   Operation     : out Theme_Operation_Access) return Boolean
is
   Length : constant Natural :=
     (if Data.Bytes = null then 0 else Data.Bytes'Length);
   Copy : RM.Image_Data_Access := null;
   Description : Terminal.App.Image_Store.Theme_Operation_Descriptor :=
     (New_Frame             => New_Frame,
      Target_Frame          => Target_Number,
      Base_Frame            => Header.Kitty_Base_Frame,
      Raw_Format            => Data.Raw_Format,
      Data_Width            => Data.Pixel_Width,
      Data_Height           => Data.Pixel_Height,
      Data_Row_Stride_Bytes => Data.Decoded_Row_Stride_Bytes,
      Target_X              => Header.Kitty_Source_X,
      Target_Y              => Header.Kitty_Source_Y,
      Composition_Mode      => Header.Kitty_Composition_Mode,
      Background_Color      => Header.Kitty_Background_Color,
      others                => <>);
begin
   Operation := null;
   if Object = null
     or else
       (Terminal.App.Image_Store.First_Theme_Operation (Object) = null
        and then Terminal.App.Image_Store.Indexed_Data (Object) = null
        and then Data.Raw_Format not in 8 | 16)
   then
      return True;
   end if;
   if not Ensure_Theme_Baseline (R, Object)
     or else Length = 0
     or else not Reserve_Theme_Operation_Bytes (R, Object, Length, 1)
   then
      return False;
   end if;
   Copy := new Terminal.Common.Bytes.Byte_Array (1 .. Length);
   Copy.all := Data.Bytes.all;
   Terminal.App.Image_Store.Create_Theme_Operation
     (Description, Copy, Operation);
   return True;
exception
   when Storage_Error | Constraint_Error =>
      Free_Image_Data (Copy);
      Terminal.App.Image_Store.Release_Unowned_Theme_Operations (Operation);
      return False;
end Prepare_Theme_Frame_Operation;
