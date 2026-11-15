with Terminal.Common.Bytes;
with Terminal.Core;

package Terminal.App.Graphics_Types is
   type Graphics_Protocol is (Sixel, Kitty, ITerm2);

   type Sixel_Color is record
      R : Terminal.Common.Bytes.Byte := 16#FF#;
      G : Terminal.Common.Bytes.Byte := 16#FF#;
      B : Terminal.Common.Bytes.Byte := 16#FF#;
      A : Terminal.Common.Bytes.Byte := 16#FF#;
   end record;
   type Sixel_Palette_State is array (Natural range 0 .. 255) of Sixel_Color;

   type Protocol_Capability is record
      Recognized : Boolean := True;
      Decoded    : Boolean := False;
      Rendered   : Boolean := False;
   end record;

   type Emoji_Capability is record
      Cluster_Preserved    : Boolean := True;
      Monochrome_Fallback  : Boolean := True;
      Color_Glyph_Rendered : Boolean := False;
   end record;

   type ITerm2_Size_Unit is
     (ITerm2_Auto, ITerm2_Cells, ITerm2_Pixels, ITerm2_Percent);

   type Graphics_Header (Protocol : Graphics_Protocol := Kitty) is record
      Recognized       : Boolean := False;
      Has_Data         : Boolean := False;
      Raw_Format       : Natural := 0;
      Pixel_Width      : Natural := 0;
      Pixel_Height     : Natural := 0;
      Placeholder_Cols : Positive := 4;
      Placeholder_Rows : Positive := 2;
      case Protocol is
         when Kitty =>
            Kitty_Control_Data_Valid : Boolean := True;
            Kitty_Action_Controls_Valid : Boolean := True;
            Kitty_More : Boolean := False;
            Kitty_More_Specified : Boolean := False;
            Kitty_More_Valid : Boolean := True;
            Kitty_Action : Character := ASCII.NUL;
            Kitty_Transmission : Character := ASCII.NUL;
            Kitty_Transmission_Specified : Boolean := False;
            Kitty_Transmission_Valid : Boolean := True;
            Kitty_Compression : Character := ASCII.NUL;
            Kitty_Compression_Specified : Boolean := False;
            Kitty_Compression_Valid : Boolean := True;
            Kitty_Delete : Character := ASCII.NUL;
            Kitty_Delete_Controls_Valid : Boolean := True;
            Kitty_Delete_Range_First : Terminal.Core.Graphics_ID := 0;
            Kitty_Delete_Range_Last : Terminal.Core.Graphics_ID := 0;
            Kitty_ID : Terminal.Core.Graphics_ID := 0;
            Kitty_Image_Number : Terminal.Core.Graphics_ID := 0;
            Kitty_Placement_ID : Terminal.Core.Graphics_ID := 0;
            Kitty_Quiet : Natural := 0;
            Kitty_Usage_Hint : Natural := 0;
            Kitty_Format : Natural := 0;
            Kitty_Data_Size : Natural := 0;
            Kitty_Data_Size_Specified : Boolean := False;
            Kitty_Data_Size_Valid : Boolean := True;
            Kitty_Data_Offset : Natural := 0;
            Kitty_Data_Offset_Specified : Boolean := False;
            Kitty_Data_Offset_Valid : Boolean := True;
            Kitty_Source_X : Natural := 0;
            Kitty_Source_Y : Natural := 0;
            Kitty_Source_Width : Natural := 0;
            Kitty_Source_Height : Natural := 0;
            Kitty_Cell_X : Natural := 0;
            Kitty_Cell_Y : Natural := 0;
            Kitty_Z_Index : Integer := 0;
            Kitty_No_Cursor_Move : Boolean := False;
            Kitty_Virtual_Placement : Boolean := False;
            Kitty_Parent_ID : Terminal.Core.Graphics_ID := 0;
            Kitty_Parent_Placement_ID : Terminal.Core.Graphics_ID := 0;
            Kitty_Parent_Offset_X : Integer := 0;
            Kitty_Parent_Offset_Y : Integer := 0;
            Kitty_Frame_Number : Natural := 0;
            Kitty_Base_Frame : Natural := 0;
            Kitty_Frame_Gap : Integer := 0;
            Kitty_Composition_Mode : Natural := 0;
            Kitty_Background_Color : Terminal.Core.Graphics_ID := 0;
            Kitty_Animation_State : Natural := 0;
            Kitty_Loop_Count : Natural := 0;
            Kitty_Columns_Specified : Boolean := False;
            Kitty_Columns_Valid : Boolean := True;
            Kitty_Rows_Specified : Boolean := False;
            Kitty_Rows_Valid : Boolean := True;
            Kitty_Geometry_Controls_Valid : Boolean := True;
         when ITerm2 =>
            ITerm2_Inline : Boolean := False;
            ITerm2_Control_Data_Valid : Boolean := True;
            ITerm2_Name_Length : Natural := 0;
            ITerm2_Declared_Size : Natural := 0;
            ITerm2_Declared_Size_Valid : Boolean := True;
            ITerm2_Preserve_Aspect_Ratio : Boolean := True;
            ITerm2_Do_Not_Move_Cursor : Boolean := False;
            ITerm2_Width_Specified : Boolean := False;
            ITerm2_Height_Specified : Boolean := False;
            ITerm2_Width_Valid : Boolean := True;
            ITerm2_Height_Valid : Boolean := True;
            ITerm2_Width_Value : Natural := 0;
            ITerm2_Height_Value : Natural := 0;
            ITerm2_Width_Unit : ITerm2_Size_Unit := ITerm2_Auto;
            ITerm2_Height_Unit : ITerm2_Size_Unit := ITerm2_Auto;
         when Sixel =>
            Sixel_Transparent : Boolean := False;
      end case;
   end record;
end Terminal.App.Graphics_Types;
