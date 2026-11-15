with Terminal.Common.Bytes;
with Terminal.App.Graphics.PNG_Types;

private package Terminal.App.Graphics.PNG_Chunks is
   use Terminal.App.Graphics.PNG_Types;

   Max_IDAT_Ranges : constant Positive := 1_024;
   type IDAT_Range_Array is
     array (Positive range 1 .. Max_IDAT_Ranges) of Natural;

   type Parsed_Image is record
      Info              : PNG_Info;
      Bit_Depth         : Natural := 0;
      Interlace         : Natural := 0;
      IDAT_First        : IDAT_Range_Array := (others => 0);
      IDAT_Size         : IDAT_Range_Array := (others => 0);
      IDAT_Count        : Natural := 0;
      IDAT_Length       : Natural := 0;
      Palette           : PNG_Palette :=
        (others => (R => 0, G => 0, B => 0, A => 16#FF#));
      Palette_Count     : Natural := 0;
      Gray_Transparent  : Natural := Natural'Last;
      Red_Transparent   : Natural := Natural'Last;
      Green_Transparent : Natural := Natural'Last;
      Blue_Transparent  : Natural := Natural'Last;
   end record;

   procedure Parse
     (Length   : Natural;
      PNG_Byte : not null access function
        (Index : Positive) return Terminal.Common.Bytes.Byte;
      Parsed   : out Parsed_Image;
      Status   : out Data_Decode_Status);
end Terminal.App.Graphics.PNG_Chunks;
