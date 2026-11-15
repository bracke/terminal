with Terminal.Common.Bytes;
with Terminal.App.Graphics.PNG_Types;

private package Terminal.App.Graphics.PNG_Pixels is
   procedure Convert_Row
     (Info              : PNG_Types.PNG_Info;
      Bit_Depth         : Natural;
      Palette           : PNG_Types.PNG_Palette;
      Palette_Count     : Natural;
      Gray_Transparent  : Natural;
      Red_Transparent   : Natural;
      Green_Transparent : Natural;
      Blue_Transparent  : Natural;
      Source            : Terminal.Common.Bytes.Byte_Array;
      Pass_Width        : Natural;
      X_Start, Y, X_Step : Natural;
      Interlaced        : Boolean;
      Destination       : in out Terminal.Common.Bytes.Byte_Array;
      Status            : out Data_Decode_Status);
end Terminal.App.Graphics.PNG_Pixels;
