separate (Terminal.App.Renderer.Theme_State)
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
     (if Terminal.App.Graphics.Has_Bytes (Data)
      then Data.Decoded_Length
      else 0);
   Copy : Terminal.App.Owned_Image_Data.Owner;
   Head : Theme_Operation_Access := null;
   Tail : Theme_Operation_Access := null;
   New_Operation : Theme_Operation_Access := null;
   Baseline_Bytes : Natural := 0;
   Baseline_Count : Natural := 0;
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
       (Themes.Count (Object) = 0
        and then not Image_Objects.Has_Stored_Indexed (Object)
        and then Data.Raw_Format not in 8 | 16)
   then
      return True;
   end if;
   if Themes.Count (Object) = 0
     and then not Prepare_Theme_Baseline
       (Object, Head, Tail, Baseline_Bytes, Baseline_Count)
   then
      return False;
   end if;
   if Length = 0
     or else Length > Natural'Last - Baseline_Bytes
     or else Baseline_Count = Natural'Last
     or else not Can_Stage_Theme_Operations
       (R, Object, Baseline_Bytes + Length, Baseline_Count + 1)
   then
      Themes.Release_Unowned (Head);
      return False;
   end if;
   Terminal.App.Owned_Image_Data.Allocate (Copy, Length);
   declare
      procedure Copy_Data (Bytes : Terminal.Common.Bytes.Byte_Array) is
      begin
         Terminal.App.Owned_Image_Data.Copy (Copy, Bytes);
      end Copy_Data;
   begin
      Terminal.App.Graphics.Read_Bytes (Data, Copy_Data'Access);
   end;
   Themes.Create
     (Description, Copy, New_Operation);
   Themes.Append_Unowned (Head, Tail, New_Operation);
   Operation := Head;
   return True;
exception
   when Storage_Error =>
      Themes.Release_Unowned (New_Operation);
      Themes.Release_Unowned (Head);
      raise;
   when Constraint_Error =>
      Themes.Release_Unowned (New_Operation);
      Themes.Release_Unowned (Head);
      return False;
end Prepare_Theme_Frame_Operation;
