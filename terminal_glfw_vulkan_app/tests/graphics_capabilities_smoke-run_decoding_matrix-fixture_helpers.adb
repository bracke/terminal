separate (Graphics_Capabilities_Smoke.Run_Decoding_Matrix)
package body Fixture_Helpers is
   function Base64_Encode
     (Data   : Jpeglib.Streams.Byte_Array;
      Length : Natural) return String
   is
      Alphabet : constant String :=
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
      Result : String (1 .. ((Length + 2) / 3) * 4);
      Out_Pos : Natural := Result'First;
      In_Pos : Natural := Data'First;
   begin
      while In_Pos <= Data'First + Length - 1 loop
         declare
            Remaining : constant Natural :=
              Data'First + Length - In_Pos;
            B1 : constant Natural := Natural (Data (In_Pos));
            B2 : constant Natural :=
              (if Remaining >= 2 then Natural (Data (In_Pos + 1)) else 0);
            B3 : constant Natural :=
              (if Remaining >= 3 then Natural (Data (In_Pos + 2)) else 0);
            Value : constant Natural := B1 * 16#10000# + B2 * 16#100# + B3;
         begin
            Result (Out_Pos) := Alphabet (Value / 16#40000# + 1);
            Result (Out_Pos + 1) :=
              Alphabet ((Value / 16#1000#) mod 64 + 1);
            Result (Out_Pos + 2) :=
              (if Remaining >= 2
               then Alphabet ((Value / 16#40#) mod 64 + 1)
               else '=');
            Result (Out_Pos + 3) :=
              (if Remaining >= 3 then Alphabet (Value mod 64 + 1) else '=');
            Out_Pos := Out_Pos + 4;
            In_Pos := In_Pos + 3;
         end;
      end loop;
      return Result;
   end Base64_Encode;

   procedure Build_JPEG is
      Destination : aliased Jpeglib.Streams.Fixed_Buffer_Destination;
      Encoder : Jpeglib.Encoding.Encoder;
      Input : constant Jpeglib.Images.Image_View :=
        (Descriptor =>
           (Width => 1,
            Height => 1,
            Format => Jpeglib.Images.RGB_24,
            Stride => 3,
            Accessible_Bytes => 3),
         Storage => JPEG_Input'Unchecked_Access);
      Outcome : Jpeglib.Results.Result;
   begin
      Jpeglib.Streams.Open (Destination, JPEG_Storage'Unchecked_Access);
      Jpeglib.Encoding.Initialize
        (Encoder,
         Destination'Access,
         (Quality => 100,
          Subsampling => Jpeglib.Encoding.Subsampling_444,
          others => <>));
      Outcome := Jpeglib.Encoding.Encode_Image (Encoder, Input);
      Assert
        (Jpeglib.Results.Succeeded (Outcome),
         "test JPEG fixture should encode");
      JPEG_Length := Natural (Jpeglib.Streams.Offset (Destination));
      Assert (JPEG_Length > 0, "test JPEG fixture length");
   end Build_JPEG;

   procedure Reset_And_Initialize_Fixtures is
   begin
      --  Keep each matrix partition independently repeatable.  The callbacks
      --  below deliberately update package state, so reset every observation
      --  before constructing the input events used by a partition.
      PNG_Row_Count := 0;
      PNG_Row_Bytes := (others => 0);
      PNG_Source_Row_Count := 0;
      PNG_Source_Row_Bytes := (others => 0);
      Base64_PNG_Encoded_Length := 0;
      Base64_PNG_Length := 0;
      Base64_PNG_Row_Count := 0;
      Base64_PNG_Row_Bytes := (others => 0);
      Base64_PNG_Invalid_Encoded_Length := 0;
      Base64_PNG_Invalid_Length := 0;
      Base64_PNG_Not_PNG_Encoded_Length := 0;
      Base64_PNG_Not_PNG_Length := 0;
      Base64_PNG_Trailing_Encoded_Length := 0;
      Base64_PNG_Trailing_Length := 0;
      Base64_PNG_Stop_Encoded_Length := 0;
      Base64_PNG_Stop_Length := 0;
      Sixel_Row_Count := 0;
      Sixel_First_Row := (others => 0);
      Raw_Row_Count := 0;
      Raw_Row_Bytes := (others => 0);
      Raw_Chunk_Row_Count := 0;
      Raw_Chunk_Row_Bytes := (others => 0);
      Zlib_Raw_Row_Count := 0;
      Zlib_Raw_Row_Bytes := (others => 0);
      Zlib_PNG_Encoded_Length := 0;
      Zlib_PNG_Row_Count := 0;
      Zlib_PNG_Row_Bytes := (others => 0);
      Base64_Byte_Count := 0;
      Base64_Bytes := (others => 0);
      Base64_Byte_Trailing_Count := 0;
      Adam7_PNG_Length := 0;
      Adam7_PNG_Bytes := (others => 0);
      Adam7_Row_Count := 0;
      Adam7_First_Row := (others => 0);
      Adam7_Second_Row := (others => 0);
      Set_Preview (Kitty, "Gf=32,a=T,i=42;SGk=");
      Set_Preview
        (ITerm2,
         "File=name=a;inline=1;width=12;height=5;doNotMoveCursor=1:SGk=");
      Set_Preview
        (ITerm2_PNG,
         "File=name=pixel.png;inline=1:iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC");
      Build_JPEG;
      declare
         JPEG_Base64 : constant String :=
           Base64_Encode (JPEG_Storage, JPEG_Length);
      begin
         Set_Preview
           (ITerm2_JPEG,
            "File=name=pixel.jpg;inline=1:" & JPEG_Base64);
         Set_Preview
           (Kitty_JPEG,
            "Gf=100,a=T,c=1,r=1;" & JPEG_Base64);
      end;
      Set_Preview
        (ITerm2_Gray_PNG,
         "File=name=gray.png;inline=1:iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAAAAAA6fptVAAAADUlEQVR4AQECAP3/AIAAggCBw24l4AAAAABJRU5ErkJggg==");
      Set_Preview
        (ITerm2_Palette_PNG,
         "File=name=pal.png;inline=1:iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAMAAAAoyzS7AAAAA1BMVEURIjOi/NOrAAAAAXRSTlNEMVdd7wAAAA1JREFUeAEBAgD9/wAAAAIAAX4FDdIAAAAASUVORK5CYII=");
      Set_Preview
        (ITerm2_Gray1_PNG,
         "File=name=gray1.png;inline=1:iVBORw0KGgoAAAANSUhEUgAAAAgAAAABAQAAAADLe9LuAAAACklEQVR4nGNYBQAArACrZgvkawAAAABJRU5ErkJggg==");
      Set_Preview
        (ITerm2_Gray2_PNG,
         "File=name=gray2.png;inline=1:iVBORw0KGgoAAAANSUhEUgAAAAQAAAABAgAAAACW50iwAAAACklEQVR4nGOQBgAAHQAcjvT1IQAAAABJRU5ErkJggg==");
      Set_Preview
        (ITerm2_Gray4_PNG,
         "File=name=gray4.png;inline=1:iVBORw0KGgoAAAANSUhEUgAAAAIAAAABBAAAAAAUuc1XAAAACklEQVR4nGP4AAAA8gDxnPEd5gAAAABJRU5ErkJggg==");
      Set_Preview
        (ITerm2_RGB16_PNG,
         "File=name=rgb16.png;inline=1:iVBORw0KGgoAAAANSUhEUgAAAAEAAAABEAIAAADA54+dAAAAD0lEQVR4nGP4/7+BgYEBAAz8An+jd5TMAAAAAElFTkSuQmCC");
      Set_Preview
        (ITerm2_GA16_PNG,
         "File=name=ga16.png;inline=1:iVBORw0KGgoAAAANSUhEUgAAAAEAAAABEAQAAADljNBBAAAADUlEQVR4nGNoYGhgAAADBQEBbmqArgAAAABJRU5ErkJggg==");
      Set_Preview
        (ITerm2_RGBA16_PNG,
         "File=name=rgba16.png;inline=1:iVBORw0KGgoAAAANSUhEUgAAAAEAAAABEAYAAABPhRjKAAAAD0lEQVR4nGP4/5+BoQEIARH6Av/MYxcQAAAAAElFTkSuQmCC");
      Set_Preview
        (ITerm2_Palette1_PNG,
         "File=name=pal1.png;inline=1:iVBORw0KGgoAAAANSUhEUgAAAAIAAAABAQMAAADO7O3JAAAABlBMVEUAAAARIjOg4Ve+AAAAAnRSTlP/RJQGtcMAAAAKSURBVHicY2gAAACCAIF3zXK2AAAAAElFTkSuQmCC");
      Set_Preview
        (ITerm2_Adam7_PNG,
         "File=name=adam7.png;inline=1:iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAYAAAEFsT2yAAAAE0lEQVR4nGP4z8AARkCC4T8YAABLxwn3Qam/GAAAAABJRU5ErkJggg==");
      Set_Preview (Kitty_Sized, "Gf=100,a=T,c=9,r=4;AAAA");
      Set_Preview (Kitty_RGBA, "Gf=32,s=1,v=1;/wAA/w==");
      Set_Preview (Kitty_Chunk, "Gf=32,s=2,v=1,m=1;/wAA");
      Set_Preview
        (Kitty_PNG,
         "Gf=100,a=T,c=1,r=1;iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC");
      Set_Preview
        (Kitty_Large_RGBA,
         "Gf=32,s=33,v=32,c=33,r=32;" & Repeat_Char ('A', 5632));
      Set_Preview
        (Kitty_Oversized_RGBA,
         "Gf=32,s=16385,v=1024,c=40,r=20;AAAA");
      Set_Preview (Kitty_Partial, "Gf=100,a=T;SG$=");
      Set_Preview (Kitty_Trailing, "Gf=100,a=T;SGk=A");
      Set_Preview (Sixel, "q??~~");
   end Reset_And_Initialize_Fixtures;

   procedure Capture_PNG_Row
     (Y : Natural;
      Row : Terminal.Common.Bytes.Byte_Array;
      Continue : in out Boolean)
   is
   begin
      PNG_Row_Count := PNG_Row_Count + 1;
      if Y /= 0 or else Row'Length /= 4 then
         Continue := False;
         return;
      end if;
      PNG_Row_Bytes := Row;
   end Capture_PNG_Row;

   function PNG_Source_Byte
     (Index : Positive) return Terminal.Common.Bytes.Byte
   is
   begin
      if Index > PNG_Row_Data'Last then
         return 0;
      end if;
      return PNG_Row_Data (Index);
   end PNG_Source_Byte;

   procedure Capture_PNG_Source_Row
     (Y : Natural;
      Row : Terminal.Common.Bytes.Byte_Array;
      Continue : in out Boolean)
   is
   begin
      PNG_Source_Row_Count := PNG_Source_Row_Count + 1;
      if Y /= 0 or else Row'Length /= 4 then
         Continue := False;
         return;
      end if;
      PNG_Source_Row_Bytes := Row;
   end Capture_PNG_Source_Row;

   function Base64_PNG_Text (Index : Positive) return String is
   begin
      case Index is
         when 1 =>
            return "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1Pe";
         when 2 =>
            return "AAAADElEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC";
         when others =>
            return "";
      end case;
   end Base64_PNG_Text;

   function Base64_PNG_Invalid_Text (Index : Positive) return String is
   begin
      if Index = 1 then
         return "%%%";
      else
         return "";
      end if;
   end Base64_PNG_Invalid_Text;

   function Base64_PNG_Not_PNG_Text (Index : Positive) return String is
   begin
      if Index = 1 then
         return "SGk=";
      else
         return "";
      end if;
   end Base64_PNG_Not_PNG_Text;

   function Base64_PNG_Trailing_Text (Index : Positive) return String is
   begin
      if Index = 1 then
         return "SGk=A";
      else
         return "";
      end if;
   end Base64_PNG_Trailing_Text;

   procedure Capture_Base64_PNG_Row
     (Y : Natural;
      Row : Terminal.Common.Bytes.Byte_Array;
      Continue : in out Boolean)
   is
   begin
      Base64_PNG_Row_Count := Base64_PNG_Row_Count + 1;
      if Y /= 0 or else Row'Length /= 4 then
         Continue := False;
         return;
      end if;
      Base64_PNG_Row_Bytes := Row;
   end Capture_Base64_PNG_Row;

   procedure Reject_Base64_PNG_Row
     (Y : Natural;
      Row : Terminal.Common.Bytes.Byte_Array;
      Continue : in out Boolean)
   is
      pragma Unreferenced (Y, Row);
   begin
      Continue := False;
   end Reject_Base64_PNG_Row;

   procedure Capture_Sixel_Row
     (Y : Natural;
      Row : Terminal.Common.Bytes.Byte_Array;
      Continue : in out Boolean)
   is
   begin
      Sixel_Row_Count := Sixel_Row_Count + 1;
      if Row'Length /= 4 then
         Continue := False;
         return;
      end if;
      if Y = 0 then
         Sixel_First_Row := Row;
      end if;
   end Capture_Sixel_Row;

   procedure Capture_Raw_Row
     (Y : Natural;
      Row : Terminal.Common.Bytes.Byte_Array;
      Continue : in out Boolean)
   is
   begin
      Raw_Row_Count := Raw_Row_Count + 1;
      if Y /= 0 or else Row'Length /= 4 then
         Continue := False;
         return;
      end if;
      Raw_Row_Bytes := Row;
   end Capture_Raw_Row;

   function Raw_Chunk_Text (Index : Positive) return String is
   begin
      case Index is
         when 1 =>
            return "/w";
         when 2 =>
            return "AA/w==";
         when others =>
            return "";
      end case;
   end Raw_Chunk_Text;

   procedure Capture_Raw_Chunk_Row
     (Y : Natural;
      Row : Terminal.Common.Bytes.Byte_Array;
      Continue : in out Boolean)
   is
   begin
      Raw_Chunk_Row_Count := Raw_Chunk_Row_Count + 1;
      if Y /= 0 or else Row'Length /= 4 then
         Continue := False;
         return;
      end if;
      Raw_Chunk_Row_Bytes := Row;
   end Capture_Raw_Chunk_Row;

   function Zlib_Raw_Chunk_Text (Index : Positive) return String is
   begin
      case Index is
         when 1 =>
            return "eJz7z8Dw";
         when 2 =>
            return "HwAE/wH/";
         when others =>
            return "";
      end case;
   end Zlib_Raw_Chunk_Text;

   function Zlib_Raw_Invalid_Text (Index : Positive) return String is
   begin
      if Index = 1 then
         return "eJz7z8DwHwAE/wHA";
      else
         return "";
      end if;
   end Zlib_Raw_Invalid_Text;

   procedure Capture_Zlib_Raw_Row
     (Y : Natural;
      Row : Terminal.Common.Bytes.Byte_Array;
      Continue : in out Boolean)
   is
   begin
      Zlib_Raw_Row_Count := Zlib_Raw_Row_Count + 1;
      if Y /= 0 or else Row'Length /= 4 then
         Continue := False;
         return;
      end if;
      Zlib_Raw_Row_Bytes := Row;
   end Capture_Zlib_Raw_Row;

   function Zlib_PNG_Chunk_Text (Index : Positive) return String is
   begin
      case Index is
         when 1 =>
            return "eJzrDPBz5+WS4mJgYOD19HAJAtKMIMzBBCQnlAff";
         when 2 =>
            return "A1I8ni6OIRVzkn+cP8DAwMzIyHDy36T3QHEGT1c/l3VOCU0Azm0QjQ==";
         when others =>
            return "";
      end case;
   end Zlib_PNG_Chunk_Text;

   procedure Capture_Zlib_PNG_Row
     (Y : Natural;
      Row : Terminal.Common.Bytes.Byte_Array;
      Continue : in out Boolean)
   is
   begin
      Zlib_PNG_Row_Count := Zlib_PNG_Row_Count + 1;
      if Y /= 0 or else Row'Length /= 4 then
         Continue := False;
         return;
      end if;
      Zlib_PNG_Row_Bytes := Row;
   end Capture_Zlib_PNG_Row;

   function Base64_Chunk_Text (Index : Positive) return String is
   begin
      case Index is
         when 1 =>
            return "SG";
         when 2 =>
            return "k=";
         when others =>
            return "";
      end case;
   end Base64_Chunk_Text;

   function Base64_Trailing_Text (Index : Positive) return String is
   begin
      if Index = 1 then
         return "SGk=A";
      else
         return "";
      end if;
   end Base64_Trailing_Text;

   procedure Capture_Base64_Byte
     (Value : Terminal.Common.Bytes.Byte;
      Continue : in out Boolean)
   is
   begin
      if Base64_Byte_Count >= Base64_Bytes'Length then
         Continue := False;
         return;
      end if;
      Base64_Byte_Count := Base64_Byte_Count + 1;
      Base64_Bytes (Base64_Byte_Count) := Value;
   end Capture_Base64_Byte;

   procedure Count_Base64_Trailing_Byte
     (Value : Terminal.Common.Bytes.Byte;
      Continue : in out Boolean)
   is
      pragma Unreferenced (Value, Continue);
   begin
      Base64_Byte_Trailing_Count := Base64_Byte_Trailing_Count + 1;
   end Count_Base64_Trailing_Byte;

   function Adam7_Base64_Text (Index : Positive) return String is
   begin
      if Index = 1 then
         return
           "iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAYAAAEFsT2yAAAAE0lEQVR4nGP4z8AARkCC4T8YAABLxwn3Qam/GAAAAABJRU5ErkJggg==";
      else
         return "";
      end if;
   end Adam7_Base64_Text;

   procedure Capture_Adam7_PNG_Byte
     (Value : Terminal.Common.Bytes.Byte;
      Continue : in out Boolean)
   is
   begin
      if Adam7_PNG_Length >= Adam7_PNG_Bytes'Length then
         Continue := False;
         return;
      end if;
      Adam7_PNG_Length := Adam7_PNG_Length + 1;
      Adam7_PNG_Bytes (Adam7_PNG_Length) := Value;
   end Capture_Adam7_PNG_Byte;

   procedure Capture_Adam7_Row
     (Y : Natural;
      Row : Terminal.Common.Bytes.Byte_Array;
      Continue : in out Boolean)
   is
   begin
      Adam7_Row_Count := Adam7_Row_Count + 1;
      if Row'Length /= 8 then
         Continue := False;
         return;
      end if;
      if Y = 0 then
         Adam7_First_Row := Row;
      elsif Y = 1 then
         Adam7_Second_Row := Row;
      else
         Continue := False;
      end if;
   end Capture_Adam7_Row;
end Fixture_Helpers;
