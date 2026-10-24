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
     & "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACAAAAAAAAAQABABEC/wwA"
     & "//4AAABIAAAASAAAAAAAAAABAAEAAAAAAAEACgAAAAAAAQABAJoAAAD/gAQAAAAA"
     & "AAEAAQAAAAQAAAAAAEgAAABIAAAAEAAgAAMACAAAAAAAAAAAAAAAAAAAAAAAAQAB"
     & "AAAAAAABAAEAQAQCEjRWAAD/";
   PDF_Base64 : constant String :=
     "JVBERi0xLjMgCjEgMCBvYmoKPDwKL1BhZ2VzIDIgMCBSCi9UeXBlIC9DYXRhbG9n"
     & "Cj4+CmVuZG9iagoyIDAgb2JqCjw8Ci9UeXBlIC9QYWdlcwovS2lkcyBbIDMgMCBS"
     & "IF0KL0NvdW50IDEKPj4KZW5kb2JqCjMgMCBvYmoKPDwKL1R5cGUgL1BhZ2UKL1Bh"
     & "cmVudCAyIDAgUgovUmVzb3VyY2VzIDw8Ci9YT2JqZWN0IDw8IC9JbTAgOCAwIFIg"
     & "Pj4KL1Byb2NTZXQgNiAwIFIgPj4KL01lZGlhQm94IFswIDAgMSAxXQovQ3JvcEJv"
     & "eCBbMCAwIDEgMV0KL0NvbnRlbnRzIDQgMCBSCi9UaHVtYiAxMSAwIFIKPj4KZW5k"
     & "b2JqCjQgMCBvYmoKPDwKL0xlbmd0aCA1IDAgUgo+PgpzdHJlYW0KcQoxIDAgMCAx"
     & "IDAgMCBjbQovSW0wIERvClEKCmVuZHN0cmVhbQplbmRvYmoKNSAwIG9iagoyNwpl"
     & "bmRvYmoKNiAwIG9iagpbIC9QREYgL1RleHQgL0ltYWdlQyBdCmVuZG9iago3IDAg"
     & "b2JqCjw8Cj4+CmVuZG9iago4IDAgb2JqCjw8Ci9UeXBlIC9YT2JqZWN0Ci9TdWJ0"
     & "eXBlIC9JbWFnZQovTmFtZSAvSW0wCi9GaWx0ZXIgWyAvUnVuTGVuZ3RoRGVjb2Rl"
     & "IF0KL1dpZHRoIDEKL0hlaWdodCAxCi9Db2xvclNwYWNlIDEwIDAgUgovQml0c1Bl"
     & "ckNvbXBvbmVudCA4Ci9MZW5ndGggOSAwIFIKPj4Kc3RyZWFtCgJlQyGACmVuZHN0"
     & "cmVhbQplbmRvYmoKOSAwIG9iago1CmVuZG9iagoxMCAwIG9iagovRGV2aWNlUkdC"
     & "CmVuZG9iagoxMSAwIG9iago8PAovRmlsdGVyIFsgL1J1bkxlbmd0aERlY29kZSBd"
     & "Ci9XaWR0aCAxCi9IZWlnaHQgMQovQ29sb3JTcGFjZSAxMCAwIFIKL0JpdHNQZXJD"
     & "b21wb25lbnQgOAovTGVuZ3RoIDEyIDAgUgo+PgpzdHJlYW0KAmVDIYAKZW5kc3Ry"
     & "ZWFtCmVuZG9iagoxMiAwIG9iago1CmVuZG9iagoxMyAwIG9iago8PAo+PgplbmRv"
     & "YmoKMTQgMCBvYmoKNQplbmRvYmoKMTUgMCBvYmoKPDwKPj4KZW5kb2JqCjE2IDAg"
     & "b2JqCjUKZW5kb2JqCjE3IDAgb2JqCjw8Ci9UaXRsZSA8RkVGRjAwNjIwMDcyMDA2"
     & "MTAwNjMwMDZCMDA2NTAwMkQwMDZGMDA2RTAwNjU+Ci9BdXRob3IgPEZFRkYwMDY4"
     & "MDA3NDAwNzQwMDcwMDA3MzAwM0EwMDJGMDAyRjAwNjkwMDZEMDA2MTAwNjcwMDY1"
     & "MDA2RDAwNjEwMDYxMDA2NzAwNjkwMDYzMDA2QjAwMkUwMDZGMDA3MjAwNjc+Ci9D"
     & "cmVhdG9yIDxGRUZGMDA2ODAwNzQwMDc0MDA3MDAwNzMwMDNBMDAyRjAwMkYwMDY5"
     & "MDA2RDAwNjEwMDYxMDA2NzAwNjUwMDZEMDA2MTAwNjcwMDY5MDA2MzAwNkIwMDJF"
     & "MDA2RjAwNzIwMDY3PgovUHJvZHVjZXIgPEZFRkYwMDY4MDA3NDAwNzQwMDcwMDA3"
     & "MzAwM0EwMDJGMDAyRjAwMkYwMDY5MDA2RDAwNjEwMDY3MDA2NTAwNkQwMDYxMDA2"
     & "NzAwNjkwMDYzMDA2QjAwMkUwMDZGMDA3MjAwNjc+Ci9DcmVhdGlvbkRhdGUgKEQ6"
     & "MjAyNjEwMjQwODAyNTgpCi9Nb2REYXRlIChEOjIwMjYxMDI0MDgwMjU4KQo+Pgpl"
     & "bmRvYmoKeHJlZgowIDE4CjAwMDAwMDAwMDAgNjU1MzUgZiAKMDAwMDAwMDAxMCAw"
     & "MDAwMCBuIAowMDAwMDAwMDU5IDAwMDAwIG4gCjAwMDAwMDAxMTggMDAwMDAgbiAK"
     & "MDAwMDAwMDI5MiAwMDAwMCBuIAowMDAwMDAwMzcyIDAwMDAwIG4gCjAwMDAwMDAz"
     & "OTAgMDAwMDAgbiAKMDAwMDAwMDQyOCAwMDAwMCBuIAowMDAwMDAwNDQ5IDAwMDAw"
     & "IG4gCjAwMDAwMDA2MzYgMDAwMDAgbiAKMDAwMDAwMDY1MyAwMDAwMCBuIAowMDAw"
     & "MDAwNjgwIDAwMDAwIG4gCjAwMDAwMDA4MjcgMDAwMDAgbiAKMDAwMDAwMDg0NSAw"
     & "MDAwMCBuIAowMDAwMDAwODY3IDAwMDAwIG4gCjAwMDAwMDA4ODUgMDAwMDAgbiAK"
     & "MDAwMDAwMDkwNyAwMDAwMCBuIAowMDAwMDAwOTI1IDAwMDAwIG4gCnRyYWlsZXIK"
     & "PDwKL1NpemUgMTgKL0luZm8gMTcgMCBSCi9Sb290IDEgMCBSCj4+CnN0YXJ0eHJl"
     & "ZgoxMzg2CiUlRU9GCg==";

   procedure Check
     (Encoded       : String;
      Expected_Red  : Natural;
      Expected_Green : Natural;
      Expected_Blue : Natural;
      Animated      : Boolean;
      Label_Text    : String)
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
        (Image.Pixel_Width = 1
         and then Image.Pixel_Height = 1
         and then Image.Frame_Bytes = 4
         and then Image.Bytes /= null,
         Label_Text & " geometry");
      Assert
        (Natural (Image.Bytes (1)) = Expected_Red
         and then Natural (Image.Bytes (2)) = Expected_Green
         and then Natural (Image.Bytes (3)) = Expected_Blue
         and then Natural (Image.Bytes (4)) = 255,
         Label_Text & " first frame pixel");
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
begin
   Assert
     (Terminal.App.Image_Media.Available,
      "native GIF media decoder should always be available");
   Check (GIF_Base64, 255, 0, 0, True, "GIF");
   Check_GIF_Limits;
   Check_GIF_Compositing;
   Check_Interlaced_GIF;
   Check_GIF87a_Still;
   Check_Transparent_Initial_Canvas;
   Check_GIF_Frame_Boundary;
   if not Terminal.App.Image_Media.Extended_Media_Available then
      Ada.Text_IO.Put_Line
        ("image_media_smoke: optional PDF/PICT checks skipped: no MagickWand runtime");
      return;
   end if;
   Check (PICT_Base64, 4, 2, 18, False, "PICT");
   Check (PDF_Base64, 101, 67, 33, False, "PDF");
end Image_Media_Smoke;
