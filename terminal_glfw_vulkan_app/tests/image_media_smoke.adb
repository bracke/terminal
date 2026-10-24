with Ada.Text_IO;
with AUnit.Assertions;

with Terminal.App.Graphics;
with Terminal.App.Image_Media;
with Terminal.App.Render_Model;
with Terminal.Common.Bytes;

procedure Image_Media_Smoke is
   use AUnit.Assertions;
   use type Terminal.App.Graphics.Data_Decode_Status;
   use type Terminal.App.Image_Media.Decode_Status;
   use type Terminal.App.Render_Model.Image_Data_Access;
   use type Terminal.Common.Bytes.Byte;
   use type Terminal.Common.Bytes.Byte_Array;

   subtype Byte is Terminal.Common.Bytes.Byte;
   subtype Byte_Array is Terminal.Common.Bytes.Byte_Array;

   GIF_Base64 : constant String :=
     "R0lGODlhAQABAPAAAP8AAAAAACH/C05FVFNDQVBFMi4wAwEBAAAh+QQABQAAACwA"
     & "AAAAAQABAAACAkQBACH5BAAHAAAALAAAAAABAAEAgAAA/wAAAAICRAEAOw==";
   Interlaced_GIF_Base64 : constant String :=
     "R0lGODlhCQAJAPMAABsWI3ImYChNXLcIaWf3GO+vH+/vWa/fKW9voS9/jtVNuBms"
     & "qm+v2xns5E/P56+f7yH5BAAAAAAAIf8LSW1hZ2VNYWdpY2sOZ2FtbWE9MC40NTQ1"
     & "NDUALAAAAAAJAAkAQAQuEMgQhh2tkX2OMUmIIE/5AIJADUq7LA7DdEUhASurpMKI"
     & "tIrXQlaqZRwOQucTAQA7";
   --  Netpbm-generated indexed fixture from pictlib's independent external
   --  conformance corpus (21 x 9, with an opaque-white first pixel).
   PICT_Base64 : constant String :=
     "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
     & "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
     & "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
     & "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
     & "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
     & "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
     & "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
     & "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
     & "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
     & "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
     & "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA9AAAAAAACQAVABEC/wwA"
     & "/////wAAAAAAAAAAABUAAAAJAAAAAAAAAAEACgAAAAAACQAVAJiAFQAAAAAACQAV"
     & "AAAAAAAAAAAASAAAAEgAAAAAAAgAAQAIAAAAAAAAAAAAAAAAAAAAAAAAAAMAAAAA"
     & "AAAAAAABAACAgP//AAL///////8AA///AAAAAAAAAAAACQAVAAAAAAAJABUAAALs"
     & "AgcBAgL6A/UCDAECAvoD/gL6AQECAgwBAgL6A/4C+gEBAgIMAQIC+gP+AvoBAQIC"
     & "DAECAvoD/gL6AQECAgf1AvoBAQICB/UC+gEBAgIE7QIAAAD/";
   --  Externally authored PICT carrying a CompressedQuickTime JPEG.
   QuickTime_PICT_Base64 : constant String :=
     "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
     & "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
     & "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
     & "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
     & "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
     & "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
     & "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
     & "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
     & "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
     & "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
     & "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACAAAAAAAACQAVABEC/wwA"
     & "//4AAABIAAAASAAAAAAAAAAJABUAAAAAAAEACgAAAAAACQAVggAAAAL+AAAAAQAA"
     & "AAAAAAAAAAAAAAAAAAEAAAAAAAAAAAAAAAAAAEAAAAAAAAAAAAAAAAAAAAAAQAAA"
     & "AAAACQAVAAADAAAAAAAAAABWanBlZwAAAAAAAAAAAAEAAWFwcGwAAAAAAAADAAAV"
     & "AAkASAAAAEgAAAAAAmQAAQtGb3RvIC0gSlBFRwAAAAAAAAAAAAAAAAAAAAAAAAAA"
     & "ABj////Y/+AAEEpGSUYAAQEAAAEAAQAA/9sAQwADAgIDAgIDAwMDBAMDBAUIBQUE"
     & "BAUKBwcGCAwKDAwLCgsLDQ4SEA0OEQ4LCxAWEBETFBUVFQwPFxgWFBgSFBUU/9sA"
     & "QwEDBAQFBAUJBQUJFA0LDRQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQU"
     & "FBQUFBQUFBQUFBQUFBQUFBQU/8AAEQgACQAVAwERAAIRAQMRAf/EABcAAQADAAAA"
     & "AAAAAAAAAAAAAAcABgn/xAApEAAABQMCBAcBAAAAAAAAAAABAgMEEQUGBwAIEhQh"
     & "IgkTFSMxR4XE/8QAGAEAAwEBAAAAAAAAAAAAAAAAAAQIBgf/xAAmEQABAgYCAgEF"
     & "AAAAAAAAAAABAhEAAwQFEiEGQQcxIhMyQlFh/9oADAMBAAIRAxEAPwBz3IYv3H3D"
     & "me4qhYTy4krUW5bkiMbmI0RCGyRVOFIVyiX3APPaEjI9ZkcTcaW6TKpaqYqw0zKb"
     & "oPpx3FP8MvnA6Ow08i9IlGoGWWUgrO1qKXV9NT/Fuyw11Fj3AZUyPhbG2I2bWsrU"
     & "2vuKSKVaM4Ii8UVcpItgMJlFAPxGA51JMA9wjMj01QXjuxUd2kTk3OXmpAl/koMS"
     & "FZfaQ/r+xGHk6+zKC6rm2VYRJmTJpSyQBhkChgpPxAB0GDem1CXs/wAk3HlDGtTq"
     & "tz1H1N+jV1WpFvITShMEUTAWEylD5OYZieuk+bWqjtFxRIokYpKAWcneSh2SfQEL"
     & "8QuVVdKBc6sXkoLIdgNMk9Afsw5a5/G4iaIIyr8dH6S/b/g0QR//2QCaAAAA/4BU"
     & "AAAAAAAJABUAAAAEAAAAAABIAAAASAAAABAAIAADAAgAAAAAAAAAAAAAAAAAAAAA"
     & "AAkAFQAAAAAACQAVAEACrQACrQACrQACrQACrQACrQACrQACrQACrQAAAP8=";

   function W (Value : Integer) return Byte_Array is
      Raw : constant Natural :=
        (if Value < 0 then Value + 16#1_0000# else Value);
   begin
      return [Byte (Raw / 256), Byte (Raw mod 256)];
   end W;

   function L (Value : Natural) return Byte_Array is
     (W (Value / 16#1_0000#) & W (Value mod 16#1_0000#));

   function Rect (Top, Left, Bottom, Right : Integer) return Byte_Array is
     (W (Top) & W (Left) & W (Bottom) & W (Right));

   function V2_Picture
     (Width, Height : Positive;
      Body_Bytes : Byte_Array) return Byte_Array is
     (W (0) & Rect (0, 0, Height, Width)
      & W (16#0011#) & W (16#02FF#) & W (16#0C00#) & W (-2) & W (0)
      & L (72 * 16#1_0000#) & L (72 * 16#1_0000#)
      & Rect (0, 0, Height, Width) & L (0) & Body_Bytes & W (16#00FF#));

   procedure Check
     (Encoded       : String;
      Expected_Red  : Natural;
      Expected_Green : Natural;
      Expected_Blue : Natural;
      Animated      : Boolean;
      Label_Text    : String;
      Expected_Width : Positive := 1;
      Expected_Height : Positive := 1)
   is
      Blob : Terminal.App.Render_Model.Image_Data_Access := null;
      Blob_Length : Natural := 0;
      Base64_Status : Terminal.App.Graphics.Data_Decode_Status;
      Holder : Terminal.App.Graphics.Graphics_Data_Preview;
      Image : Terminal.App.Image_Media.Decoded_Image;
      Status : Terminal.App.Image_Media.Decode_Status;
   begin
      Terminal.App.Graphics.Decode_Base64_Data
        (Encoded, 1_048_576, Blob, Blob_Length, Base64_Status);
      Ada.Text_IO.Put_Line
        (Label_Text & " base64="
         & Terminal.App.Graphics.Data_Decode_Status'Image (Base64_Status)
         & " bytes=" & Natural'Image (Blob_Length));
      Assert
        (Base64_Status = Terminal.App.Graphics.Decode_Ok and then Blob /= null,
         Label_Text & " base64 decode");
      Terminal.App.Image_Media.Decode
        (Blob.all, Blob_Length, 1_048_576, 4_096, Image, Status);
      Ada.Text_IO.Put_Line
        (Label_Text & " media="
         & Terminal.App.Image_Media.Decode_Status'Image (Status)
         & " frames=" & Natural'Image (Image.Frame_Count));
      Holder.Bytes := Blob;
      Blob := null;
      Terminal.App.Graphics.Release (Holder);
      Assert (Status = Terminal.App.Image_Media.Decode_Ok, Label_Text & " decode");
      Assert
        (Image.Pixel_Width = Expected_Width
         and then Image.Pixel_Height = Expected_Height
         and then Image.Frame_Bytes = Expected_Width * Expected_Height * 4
         and then Image.Bytes /= null,
         Label_Text & " geometry");
      Assert
        (Natural (Image.Bytes (1)) = Expected_Red
         and then Natural (Image.Bytes (2)) = Expected_Green
         and then Natural (Image.Bytes (3)) = Expected_Blue
         and then Natural (Image.Bytes (4)) = 255,
         Label_Text & " first frame pixel");
      Assert
        (Image.Adapter_Buffer_Bytes >= Image.Total_Bytes
         and then Image.Decoder_Configured_Bytes > 0,
         Label_Text & " reports explicit buffers and configured decoder memory");
      if Label_Text = "PICT" or else Label_Text = "PICT QuickTime JPEG" then
         Assert
           (Image.Adapter_Buffer_Bytes = Image.Frame_Bytes * 2
            and then Image.Decoder_Configured_Bytes = 1_048_576,
            Label_Text & " reports adapter buffers and aggregate decoder limits");
      end if;
      if Animated then
         Assert
           (Image.Frame_Count = 2
            and then Image.Total_Bytes = 8
            and then Image.Loop_Count = 2
            and then Image.Delays_MS (1) = 50
            and then Image.Delays_MS (2) = 70
            and then Natural (Image.Bytes (7)) = 255,
            "animated GIF frames and timing");
      else
         Assert (Image.Frame_Count = 1, Label_Text & " frame count");
      end if;
      Terminal.App.Image_Media.Release (Image);
   end Check;

   procedure Check_GIF_Limits is
      Blob : Terminal.App.Render_Model.Image_Data_Access := null;
      Blob_Length : Natural := 0;
      Base64_Status : Terminal.App.Graphics.Data_Decode_Status;
      Holder : Terminal.App.Graphics.Graphics_Data_Preview;
      Image : Terminal.App.Image_Media.Decoded_Image;
      Status : Terminal.App.Image_Media.Decode_Status;
      Truncated : constant Terminal.Common.Bytes.Byte_Array :=
        [Character'Pos ('G'), Character'Pos ('I'), Character'Pos ('F'),
         Character'Pos ('8'), Character'Pos ('9'), Character'Pos ('a')];
   begin
      Terminal.App.Graphics.Decode_Base64_Data
        (GIF_Base64, 1_048_576, Blob, Blob_Length, Base64_Status);
      Assert
        (Base64_Status = Terminal.App.Graphics.Decode_Ok and then Blob /= null,
         "GIF limit fixture decode");
      Terminal.App.Image_Media.Decode
        (Blob.all, Blob_Length, 4, 4_096, Image, Status);
      Assert
        (Status = Terminal.App.Image_Media.Decode_Too_Large
         and then Image.Bytes = null,
         "GIF animation must respect the total decoded-byte limit");
      Holder.Bytes := Blob;
      Blob := null;
      Terminal.App.Graphics.Release (Holder);

      Terminal.App.Image_Media.Decode
        (Truncated,
         Truncated'Length,
         1_048_576,
         4_096,
         Image,
         Status);
      Assert
        (Status = Terminal.App.Image_Media.Decode_Invalid
         and then Image.Bytes = null,
         "truncated GIF must fail without publishing pixels");
   end Check_GIF_Limits;

   procedure Check_Unsupported_Media is
      PDF_Header : constant Byte_Array :=
        [Character'Pos ('%'), Character'Pos ('P'), Character'Pos ('D'),
         Character'Pos ('F'), Character'Pos ('-')];
      Image : Terminal.App.Image_Media.Decoded_Image;
      Status : Terminal.App.Image_Media.Decode_Status;
   begin
      Terminal.App.Image_Media.Decode
        (PDF_Header,
         PDF_Header'Length,
         1_048_576,
         4_096,
         Image,
         Status);
      Assert
        (Status = Terminal.App.Image_Media.Decode_Unavailable
         and then Image.Bytes = null,
         "unsupported inline media must not use an optional runtime decoder");
   end Check_Unsupported_Media;

   function GIF_Header return Byte_Array is
   begin
      return
        [71, 73, 70, 56, 57, 97,
         2, 0, 1, 0, 16#81#, 0, 0,
         0, 0, 0, 255, 0, 0, 0, 255, 0, 0, 0, 255];
   end GIF_Header;

   function GIF_GCE
     (Disposal         : Natural;
      Transparent      : Boolean := False;
      Transparent_Index : Byte := 0) return Byte_Array
   is
      Packed : constant Byte :=
        Byte (Disposal * 4 + (if Transparent then 1 else 0));
   begin
      return
        [16#21#, 16#F9#, 4, Packed, 0, 0, Transparent_Index, 0];
   end GIF_GCE;

   function GIF_One_Pixel
     (Left, Palette_Index : Natural) return Byte_Array
   is
      Packed_Data : constant Byte := Byte (16#44# + Palette_Index * 8);
   begin
      return
        [16#2C#, Byte (Left), 0, 0, 0, 1, 0, 1, 0, 0,
         2, 2, Packed_Data, 1, 0];
   end GIF_One_Pixel;

   function GIF_Two_Red_Pixels return Byte_Array is
   begin
      return
        [16#2C#, 0, 0, 0, 0, 2, 0, 1, 0, 0,
         2, 2, 16#4C#, 16#0A#, 0];
   end GIF_Two_Red_Pixels;

   procedure Check_GIF_Compositing is
      Fixture : constant Byte_Array :=
        GIF_Header
        & GIF_GCE (1) & GIF_Two_Red_Pixels
        & GIF_GCE (2) & GIF_One_Pixel (0, 2)
        & GIF_GCE (3) & GIF_One_Pixel (1, 3)
        & GIF_GCE (1, True, 0) & GIF_One_Pixel (0, 0)
        & [16#3B#];
      Image : Terminal.App.Image_Media.Decoded_Image;
      Status : Terminal.App.Image_Media.Decode_Status;

      procedure Assert_Pixel
        (Frame, X : Positive;
         Red, Green, Blue, Alpha : Natural;
         Label_Text : String)
      is
         First : constant Positive :=
           Image.Bytes'First
           + (Frame - 1) * Image.Frame_Bytes
           + (X - 1) * 4;
      begin
         Assert
           (Natural (Image.Bytes (First)) = Red
            and then Natural (Image.Bytes (First + 1)) = Green
            and then Natural (Image.Bytes (First + 2)) = Blue
            and then Natural (Image.Bytes (First + 3)) = Alpha,
            Label_Text);
      end Assert_Pixel;
   begin
      Terminal.App.Image_Media.Decode
        (Fixture, Fixture'Length, 1_048_576, 4_096, Image, Status);
      Assert
        (Status = Terminal.App.Image_Media.Decode_Ok
         and then Image.Pixel_Width = 2
         and then Image.Pixel_Height = 1
         and then Image.Frame_Count = 4
         and then Image.Loop_Count = 0
         and then Image.Frame_Bytes = 8
         and then Image.Total_Bytes = 32
         and then Image.Bytes /= null,
         "GIF compositing fixture metadata");
      Assert_Pixel (1, 1, 255, 0, 0, 255, "GIF initial left pixel");
      Assert_Pixel (1, 2, 255, 0, 0, 255, "GIF initial right pixel");
      Assert_Pixel (2, 1, 0, 255, 0, 255, "GIF offset frame draw");
      Assert_Pixel (2, 2, 255, 0, 0, 255, "GIF retained canvas pixel");
      Assert_Pixel (3, 1, 0, 0, 0, 255, "GIF disposal 2 background");
      Assert_Pixel (3, 2, 0, 0, 255, 255, "GIF disposal 3 frame draw");
      Assert_Pixel (4, 1, 0, 0, 0, 255, "GIF transparent pixel");
      Assert_Pixel (4, 2, 255, 0, 0, 255, "GIF disposal 3 restore");
      Terminal.App.Image_Media.Release (Image);
   end Check_GIF_Compositing;

   procedure Check_Interlaced_GIF is
      Blob : Terminal.App.Render_Model.Image_Data_Access := null;
      Blob_Length : Natural := 0;
      Base64_Status : Terminal.App.Graphics.Data_Decode_Status;
      Holder : Terminal.App.Graphics.Graphics_Data_Preview;
      Image : Terminal.App.Image_Media.Decoded_Image;
      Status : Terminal.App.Image_Media.Decode_Status;

      procedure Assert_Pixel
        (X, Y : Natural;
         Red, Green, Blue : Natural;
         Label_Text : String)
      is
         First : constant Positive :=
           Image.Bytes'First + (Y * Image.Pixel_Width + X) * 4;
      begin
         Assert
           (Natural (Image.Bytes (First)) = Red
            and then Natural (Image.Bytes (First + 1)) = Green
            and then Natural (Image.Bytes (First + 2)) = Blue
            and then Natural (Image.Bytes (First + 3)) = 255,
            Label_Text);
      end Assert_Pixel;
   begin
      Terminal.App.Graphics.Decode_Base64_Data
        (Interlaced_GIF_Base64,
         1_048_576,
         Blob,
         Blob_Length,
         Base64_Status);
      Assert
        (Base64_Status = Terminal.App.Graphics.Decode_Ok and then Blob /= null,
         "interlaced GIF fixture decode");
      Terminal.App.Image_Media.Decode
        (Blob.all, Blob_Length, 1_048_576, 4_096, Image, Status);
      Holder.Bytes := Blob;
      Blob := null;
      Terminal.App.Graphics.Release (Holder);
      Assert
        (Status = Terminal.App.Image_Media.Decode_Ok
         and then Image.Pixel_Width = 9
         and then Image.Pixel_Height = 9
         and then Image.Frame_Count = 1
         and then Image.Loop_Count = 0
         and then Image.Frame_Bytes = 324
         and then Image.Bytes /= null,
         "interlaced GIF metadata and single-play policy");
      Assert_Pixel (0, 0, 27, 22, 35, "interlaced GIF first pass row");
      Assert_Pixel (7, 1, 213, 77, 184, "interlaced GIF second row");
      Assert_Pixel (1, 2, 40, 77, 92, "interlaced GIF reordered row");
      Assert_Pixel (0, 8, 25, 236, 228, "interlaced GIF final row");
      Terminal.App.Image_Media.Release (Image);
   end Check_Interlaced_GIF;

   procedure Check_GIF87a_Still is
      Fixture : constant Byte_Array :=
        [71, 73, 70, 56, 55, 97,
         1, 0, 1, 0, 16#80#, 0, 0,
         255, 0, 0, 0, 0, 0,
         16#2C#, 0, 0, 0, 0, 1, 0, 1, 0, 0,
         2, 2, 16#44#, 1, 0, 16#3B#];
      Image : Terminal.App.Image_Media.Decoded_Image;
      Status : Terminal.App.Image_Media.Decode_Status;
   begin
      Terminal.App.Image_Media.Decode
        (Fixture, Fixture'Length, 1_048_576, 4_096, Image, Status);
      Assert
        (Status = Terminal.App.Image_Media.Decode_Ok
         and then Image.Pixel_Width = 1
         and then Image.Pixel_Height = 1
         and then Image.Frame_Count = 1
         and then Image.Loop_Count = 0
         and then Image.Frame_Bytes = 4
         and then Image.Total_Bytes = 4
         and then Image.Bytes /= null
         and then Natural (Image.Bytes (Image.Bytes'First)) = 255
         and then Natural (Image.Bytes (Image.Bytes'First + 1)) = 0
         and then Natural (Image.Bytes (Image.Bytes'First + 2)) = 0
         and then Natural (Image.Bytes (Image.Bytes'First + 3)) = 255,
         "GIF87a still-image decoding");
      Terminal.App.Image_Media.Release (Image);
   end Check_GIF87a_Still;

   procedure Check_Transparent_Initial_Canvas is
      Fixture : constant Byte_Array :=
        [71, 73, 70, 56, 57, 97,
         2, 0, 1, 0, 0, 0, 0,
         16#2C#, 1, 0, 0, 0, 1, 0, 1, 0, 16#80#,
         0, 0, 0, 255, 255, 255,
         2, 2, 16#4C#, 1, 0, 16#3B#];
      Image : Terminal.App.Image_Media.Decoded_Image;
      Status : Terminal.App.Image_Media.Decode_Status;
   begin
      Terminal.App.Image_Media.Decode
        (Fixture, Fixture'Length, 1_048_576, 4_096, Image, Status);
      Assert
        (Status = Terminal.App.Image_Media.Decode_Ok
         and then Image.Pixel_Width = 2
         and then Image.Pixel_Height = 1
         and then Image.Frame_Count = 1
         and then Image.Frame_Bytes = 8
         and then Image.Bytes /= null
         and then Natural (Image.Bytes (Image.Bytes'First)) = 0
         and then Natural (Image.Bytes (Image.Bytes'First + 1)) = 0
         and then Natural (Image.Bytes (Image.Bytes'First + 2)) = 0
         and then Natural (Image.Bytes (Image.Bytes'First + 3)) = 0
         and then Natural (Image.Bytes (Image.Bytes'First + 4)) = 255
         and then Natural (Image.Bytes (Image.Bytes'First + 5)) = 255
         and then Natural (Image.Bytes (Image.Bytes'First + 6)) = 255
         and then Natural (Image.Bytes (Image.Bytes'First + 7)) = 255,
         "GIF initial canvas preserves transparent alpha");
      Terminal.App.Image_Media.Release (Image);
   end Check_Transparent_Initial_Canvas;

   function Many_Frame_GIF (Count : Positive) return Byte_Array is
      Header : constant Byte_Array := GIF_Header;
      Frame : constant Byte_Array := GIF_One_Pixel (0, 1);
      Result : Byte_Array
        (1 .. Header'Length + Count * Frame'Length + 1);
      Position : Positive := Result'First;
   begin
      Result (Position .. Position + Header'Length - 1) := Header;
      Position := Position + Header'Length;
      for Number in 1 .. Count loop
         pragma Unreferenced (Number);
         Result (Position .. Position + Frame'Length - 1) := Frame;
         Position := Position + Frame'Length;
      end loop;
      Result (Position) := 16#3B#;
      return Result;
   end Many_Frame_GIF;

   procedure Check_GIF_Frame_Boundary is
      At_Limit : constant Byte_Array := Many_Frame_GIF (256);
      Over_Limit : constant Byte_Array := Many_Frame_GIF (257);
      Image : Terminal.App.Image_Media.Decoded_Image;
      Status : Terminal.App.Image_Media.Decode_Status;
   begin
      Terminal.App.Image_Media.Decode
        (At_Limit, At_Limit'Length, 1_048_576, 4_096, Image, Status);
      Assert
        (Status = Terminal.App.Image_Media.Decode_Ok
         and then Image.Frame_Count = 256
         and then Image.Pixel_Width = 2
         and then Image.Pixel_Height = 1
         and then Image.Frame_Bytes = 8
         and then Image.Total_Bytes = 2_048
         and then Image.Bytes /= null,
         "GIF accepts the compiled 256-frame boundary");
      Terminal.App.Image_Media.Release (Image);

      Terminal.App.Image_Media.Decode
        (Over_Limit,
         Over_Limit'Length,
         1_048_576,
         4_096,
         Image,
         Status);
      Assert
        (Status = Terminal.App.Image_Media.Decode_Too_Large
         and then Image.Bytes = null
         and then Image.Frame_Count = 0,
         "GIF rejects frame 257 without publishing pixels");
   end Check_GIF_Frame_Boundary;

   procedure Check_PICT_Vector_And_Text is
      Vector : constant Byte_Array :=
        V2_Picture (6, 4, W (16#31#) & Rect (1, 2, 3, 5));
      Text_Picture : constant Byte_Array :=
        V2_Picture
          (48, 24,
           W (16#03#) & W (21)
           & W (16#0D#) & W (12)
           & W (16#28#) & W (15) & W (2)
           & [Byte (2), Byte (Character'Pos ('H')),
              Byte (Character'Pos ('i')), Byte (0)]);
      Image : Terminal.App.Image_Media.Decoded_Image;
      Status : Terminal.App.Image_Media.Decode_Status;
      Ink_Found : Boolean := False;
      Vector_Pixel : constant Natural := (1 * 6 + 2) * 4 + 1;
   begin
      Terminal.App.Image_Media.Decode
        (Vector, Vector'Length, 1_048_576, 4_096, Image, Status);
      Assert
        (Status = Terminal.App.Image_Media.Decode_Ok
         and then Image.Pixel_Width = 6
         and then Image.Pixel_Height = 4
         and then Image.Bytes /= null
         and then Image.Bytes (Vector_Pixel) = 0
         and then Image.Bytes (Vector_Pixel + 1) = 0
         and then Image.Bytes (Vector_Pixel + 2) = 0
         and then Image.Bytes (Vector_Pixel + 3) = 255,
         "PICT QuickDraw vector paint is rasterized");
      Terminal.App.Image_Media.Release (Image);

      Terminal.App.Image_Media.Decode
        (Text_Picture,
         Text_Picture'Length,
         1_048_576,
         4_096,
         Image,
         Status);
      Assert
        (Status = Terminal.App.Image_Media.Decode_Ok
         and then Image.Bytes /= null,
         "PICT QuickDraw text and classic Helvetica mapping decode");
      for I in 0 .. Image.Pixel_Width * Image.Pixel_Height - 1 loop
         declare
            First : constant Positive := Image.Bytes'First + I * 4;
         begin
            if Image.Bytes (First) < 250
              or else Image.Bytes (First + 1) < 250
              or else Image.Bytes (First + 2) < 250
            then
               Ink_Found := True;
               exit;
            end if;
         end;
      end loop;
      Assert (Ink_Found, "PICT QuickDraw text produces visible glyph pixels");
      Terminal.App.Image_Media.Release (Image);
   end Check_PICT_Vector_And_Text;

   procedure Check_PICT_Compatibility_Warning is
      Fixture : constant Byte_Array :=
        V2_Picture
          (48, 24,
           W (16#04#) & [Byte (8), Byte (0)]
           & W (16#28#) & W (15) & W (2)
           & [Byte (2), Byte (Character'Pos ('H')),
              Byte (Character'Pos ('i')), Byte (0)]);
      Image : Terminal.App.Image_Media.Decoded_Image;
      Status : Terminal.App.Image_Media.Decode_Status;
   begin
      Terminal.App.Image_Media.Decode
        (Fixture, Fixture'Length, 1_048_576, 4_096, Image, Status);
      Assert
        (Status = Terminal.App.Image_Media.Decode_Ok
         and then Image.Bytes /= null
         and then Image.Warning_Count > 0
         and then Image.First_Warning.Present
         and then Terminal.App.Image_Media.Diagnostic_Identifier
           (Image.First_Warning) = "pict.warning.approximated",
         "unsupported PICT drawing should render compatibly with a warning");
      Terminal.App.Image_Media.Release (Image);
   end Check_PICT_Compatibility_Warning;

   procedure Check_PICT_Bounds_And_Headers is
      Blob : Terminal.App.Render_Model.Image_Data_Access := null;
      Blob_Length : Natural := 0;
      Base64_Status : Terminal.App.Graphics.Data_Decode_Status;
      Holder : Terminal.App.Graphics.Graphics_Data_Preview;
      Image : Terminal.App.Image_Media.Decoded_Image;
      Status : Terminal.App.Image_Media.Decode_Status;
   begin
      Terminal.App.Graphics.Decode_Base64_Data
        (PICT_Base64, 1_048_576, Blob, Blob_Length, Base64_Status);
      Assert
        (Base64_Status = Terminal.App.Graphics.Decode_Ok and then Blob /= null,
         "PICT bounds fixture decode");

      Terminal.App.Image_Media.Decode
        (Blob.all, Blob_Length, 4, 4_096, Image, Status);
      Assert
        (Status = Terminal.App.Image_Media.Decode_Too_Large
         and then Image.Bytes = null,
         "PICT canvas obeys the decoded-byte limit");

      Terminal.App.Image_Media.Decode
        (Blob.all (Blob.all'First + 512 .. Blob.all'First + Blob_Length - 1),
         Blob_Length - 512,
         1_048_576,
         4_096,
         Image,
         Status);
      Assert
        (Status = Terminal.App.Image_Media.Decode_Ok
         and then Image.Pixel_Width = 21
         and then Image.Pixel_Height = 9,
         "headerless PICT is decoded natively");
      Terminal.App.Image_Media.Release (Image);

      Terminal.App.Image_Media.Decode
        (Blob.all (Blob.all'First .. Blob.all'First + 521),
         522,
         1_048_576,
         4_096,
         Image,
         Status);
      Assert
        (Status = Terminal.App.Image_Media.Decode_Invalid
         and then Image.Bytes = null
         and then Image.Diagnostic.Present
         and then Image.Diagnostic.Identifier_Length > 0
         and then Terminal.App.Image_Media.Diagnostic_Identifier
           (Image.Diagnostic)'Length > 0,
         "truncated headered PICT fails without fallback pixels");

      Holder.Bytes := Blob;
      Blob := null;
      Terminal.App.Graphics.Release (Holder);
   end Check_PICT_Bounds_And_Headers;
begin
   Assert
     (Terminal.App.Image_Media.Available,
      "native GIF media decoder should always be available");
   Check_Unsupported_Media;
   Check (GIF_Base64, 255, 0, 0, True, "GIF");
   Check_GIF_Limits;
   Check_GIF_Compositing;
   Check_Interlaced_GIF;
   Check_GIF87a_Still;
   Check_Transparent_Initial_Canvas;
   Check_GIF_Frame_Boundary;
   Check
     (PICT_Base64,
      255,
      255,
      255,
      False,
      "PICT",
      Expected_Width => 21,
      Expected_Height => 9);
   Check_PICT_Bounds_And_Headers;
   Check_PICT_Vector_And_Text;
   Check_PICT_Compatibility_Warning;
   Check
     (QuickTime_PICT_Base64,
      251,
      255,
      255,
      False,
      "PICT QuickTime JPEG",
      Expected_Width => 21,
      Expected_Height => 9);
end Image_Media_Smoke;
