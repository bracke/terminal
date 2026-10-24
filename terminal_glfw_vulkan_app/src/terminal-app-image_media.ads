with Terminal.Common.Bytes;
with Terminal.App.Render_Model;
with Interfaces;

package Terminal.App.Image_Media is
   Max_Frames : constant := 256;

   type Decode_Status is
     (Decode_Ok,
      Decode_Unavailable,
      Decode_Invalid,
      Decode_Too_Large,
      Decode_Allocation_Failed);

   type Frame_Delay_Array is array (Positive range 1 .. Max_Frames) of Natural;

   Max_Diagnostic_Identifier_Length : constant := 96;

   type Decode_Limit_Kind is
     (No_Limit,
      Frame_Width_Limit,
      Frame_Height_Limit,
      Canvas_Pixel_Limit,
      Picture_Byte_Limit,
      Opcode_Count_Limit,
      Opcode_Byte_Limit,
      Region_Byte_Limit,
      Polygon_Point_Limit,
      Drawing_Work_Limit,
      Retained_Metadata_Byte_Limit,
      Metadata_Item_Limit,
      Allocation_Byte_Limit,
      Output_Byte_Limit,
      Embedded_Image_Byte_Limit,
      Embedded_Image_Pixel_Limit,
      Warning_Record_Limit);

   type Decode_Diagnostic is record
      Present : Boolean := False;
      Identifier_Length : Natural range 0 .. Max_Diagnostic_Identifier_Length := 0;
      Identifier : String (1 .. Max_Diagnostic_Identifier_Length) :=
        (others => ASCII.NUL);
      Source_Offset : Interfaces.Unsigned_64 := 0;
      Destination_Offset : Interfaces.Unsigned_64 := 0;
      Has_Opcode : Boolean := False;
      Opcode : Natural := 0;
      Opcode_Ordinal : Interfaces.Unsigned_64 := 0;
      Row : Interfaces.Unsigned_64 := 0;
      Expected : Interfaces.Unsigned_64 := 0;
      Actual : Interfaces.Unsigned_64 := 0;
      Limit : Decode_Limit_Kind := No_Limit;
      Has_Underlying_Code : Boolean := False;
      Underlying_Code : Long_Long_Integer := 0;
   end record;

   function Diagnostic_Identifier (Item : Decode_Diagnostic) return String;

   type Decoded_Image is record
      Pixel_Width  : Natural := 0;
      Pixel_Height : Natural := 0;
      Frame_Count  : Natural range 0 .. Max_Frames := 0;
      Loop_Count   : Natural := 1;
      Frame_Bytes  : Natural := 0;
      Total_Bytes  : Natural := 0;
      --  Peak bytes simultaneously owned by this adapter while decoding;
      --  decoder-internal workspaces have their own configured limits. Native
      --  PICT input is borrowed and its renderer writes directly into Bytes.
      Peak_Working_Bytes : Natural := 0;
      Delays_MS    : Frame_Delay_Array := (others => 100);
      Bytes        : Terminal.App.Render_Model.Image_Data_Access := null;
      Diagnostic   : Decode_Diagnostic;
   end record;

   --  Native GIF and PICT decoding is always available. Other media formats
   --  remain an optional runtime extension supplied by MagickWand.
   function Available return Boolean;
   function Extended_Media_Available return Boolean;

   procedure Decode
     (Data                    : Terminal.Common.Bytes.Byte_Array;
      Length                  : Natural;
      Maximum_Decoded_Bytes   : Positive;
      Maximum_Pixel_Dimension : Positive;
      Result                  : in out Decoded_Image;
      Status                  : out Decode_Status);

   procedure Release (Result : in out Decoded_Image);
end Terminal.App.Image_Media;
