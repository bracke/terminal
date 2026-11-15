with Graphics_Capabilities_Fixtures;
with AUnit.Assertions;
with Ada.Text_IO;

with Jpeglib.Encoding;
with Jpeglib.Images;
with Jpeglib.Results;
with Jpeglib.Streams;

with Terminal.App.Graphics;
with Terminal.App.Graphics.Media_Decoders;
with Terminal.App.Graphics.Decoder_Testing;
with Terminal.App.Owned_Image_Data;
with Terminal.App.Render_Model;
with Terminal.Common.Bytes;
with Terminal.Common.Status;
with Terminal.Core;

procedure Graphics_Capabilities_Smoke is
   use type Terminal.App.Graphics.Data_Decode_Status;
   use type Terminal.App.Graphics.ITerm2_Size_Unit;
   use type Terminal.App.Render_Model.Image_Data_View;
   use type Terminal.App.Render_Model.Image_Decode_Status;
   use type Terminal.App.Render_Model.Image_Decoded_Source_Kind;
   use type Terminal.Common.Bytes.Byte;
   use type Terminal.Core.Graphics_ID;
   use type Jpeglib.Destination_Offset;

   package Graphics renames Terminal.App.Graphics;
   package Media_Decoding renames
     Terminal.App.Graphics.Media_Decoders;
   package Transport_Decoding renames
     Terminal.App.Graphics.Decoder_Testing;
   package RM renames Terminal.App.Render_Model;

   procedure Assert (Condition : Boolean; Message : String) is
   begin
      if not Condition then
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error, "FAILED: " & Message);
         AUnit.Assertions.Assert (False, Message);
      end if;
   end Assert;

   procedure Set_Preview
     (Event : in out Terminal.Core.Graphics_Event;
      Text  : String)
   is
   begin
      Event.Payload_Length := Text'Length;
      Event.Preview_Length := Text'Length;
      Event.Preview := (others => ASCII.NUL);
      Event.Preview (1 .. Text'Length) := Text;
   end Set_Preview;

   function Repeat_Char (Ch : Character; Count : Natural) return String is
      Result : String (1 .. Count);
   begin
      for I in Result'Range loop
         Result (I) := Ch;
      end loop;
      return Result;
   end Repeat_Char;

   procedure Assert_Protocol
     (Protocol : Graphics.Graphics_Protocol;
      Label    : String;
      Decoded  : Boolean := False)
   is
      Cap : constant Graphics.Protocol_Capability :=
        Graphics.Capability (Protocol);
      Runtime_Cap : constant Graphics.Protocol_Capability :=
        Graphics.Capability (Protocol, Rendering_Available => True);
   begin
      Assert (Cap.Recognized, Label & " should be recognized");
      Assert (Cap.Decoded = Decoded, Label & " decode support flag");
      Assert
        (not Cap.Rendered,
         Label & " should not infer runtime rendering availability");
      Assert
        (Runtime_Cap.Rendered,
         Label & " should report confirmed runtime rendering support");
   end Assert_Protocol;

   procedure Assert_Graphics_Label
     (Protocol : Terminal.Core.Graphics_Protocol_Kind;
      Payload_Length : Natural;
      Expected : String;
      Label    : String)
   is
      Diagnostics : Terminal.Core.Diagnostic_Snapshot :=
        (others => <>);
   begin
      Diagnostics.Graphics_Commands_Received := 1;
      Diagnostics.Last_Graphics_Protocol := Protocol;
      Diagnostics.Last_Graphics_Payload_Length := Payload_Length;
      Assert
        (Graphics.Graphics_Status_Label (Diagnostics) = Expected,
         Label);
   end Assert_Graphics_Label;

   procedure Run_Decoding_Matrix is separate;
begin
   Assert
     (Graphics.Data_Decode_Byte_Limit'Last =
        Graphics.Max_Data_Preview_Length,
      "public decode limit must fit the bounded graphics result");
   declare
      Bytes : constant Terminal.Common.Bytes.Byte_Array :=
        (1 => 16#00#, 2 => 16#41#, 3 => 16#FF#, 4 => 16#10#, 5 => 16#22#);
   begin
      Assert
        (Terminal.Common.Status.Preview_Bytes_Label (Bytes, 0) = "",
         "empty preview byte label");
      Assert
        (Terminal.Common.Status.Preview_Bytes_Label (Bytes, 3) =
         " bytes=0041FF",
         "preview byte label should render requested bytes");
      Assert
        (Terminal.Common.Status.Preview_Bytes_Label (Bytes, 5) =
         " bytes=0041FF10",
         "preview byte label should default to four bytes");
      Assert
        (Terminal.Common.Status.Preview_Bytes_Label (Bytes, 5, 2) =
         " bytes=0041",
         "preview byte label should respect explicit limit");
   end;

   Assert_Protocol (Graphics.Sixel, "sixel", Decoded => True);
   Assert_Protocol (Graphics.Kitty, "kitty graphics", Decoded => True);
   Assert_Protocol (Graphics.ITerm2, "iTerm2 image", Decoded => True);

   declare
      Emoji : constant Graphics.Emoji_Capability := Graphics.Color_Emoji;
      Runtime_Emoji : constant Graphics.Emoji_Capability :=
        Graphics.Color_Emoji (Color_Font_Available => True);
   begin
      Assert (Emoji.Cluster_Preserved, "emoji clusters should be preserved");
      Assert
        (Emoji.Monochrome_Fallback,
         "emoji should report monochrome fallback path");
      Assert
        (not Emoji.Color_Glyph_Rendered,
         "emoji should not infer color-font availability");
      Assert
        (Runtime_Emoji.Color_Glyph_Rendered,
         "emoji should report confirmed color glyph rendering");
   end;

   Assert (Graphics.Name (Graphics.Sixel) = "sixel", "sixel name");
   Assert (Graphics.Name (Graphics.Kitty) = "kitty", "kitty name");
   Assert (Graphics.Name (Graphics.ITerm2) = "iTerm2", "iTerm2 name");
   Assert
     (Graphics.Data_Decode_Status_Suffix (Graphics.Decode_Ok) = "",
      "ok data decode suffix");
   Assert
     (Graphics.Data_Decode_Status_Suffix (Graphics.Decode_Invalid_Byte) =
      " invalid-byte",
      "invalid-byte data decode suffix");
   Assert
     (Graphics.Data_Decode_Status_Suffix (Graphics.Decode_Trailing_Data) =
      " trailing-data",
      "trailing-data data decode suffix");
   Assert
     (Graphics.Data_Decode_Status_Suffix (Graphics.Decode_Preview_Truncated) =
      " truncated",
      "truncated data decode suffix");
   Assert
     (Graphics.Data_Decode_Status_Suffix (Graphics.Decode_Invalid_Data) =
      " invalid-data",
      "invalid-data decode suffix");
   Assert
     (Graphics.Data_Decode_Status_Suffix (Graphics.Decode_Too_Large) =
      " too-large",
      "too-large decode suffix");
   Assert
     (Graphics.Data_Decode_Status_Suffix (Graphics.Decode_Allocation_Failed) =
      " allocation-failed",
      "allocation-failed decode suffix");
   Assert
     (Graphics.Data_Decode_Status_Suffix (Graphics.Decode_Unsupported_Format) =
      " unsupported-format",
      "unsupported-format data decode suffix");
   Assert
     (Graphics.Image_Decode_Status (Graphics.Decode_Not_Attempted) =
      Terminal.App.Render_Model.Image_Decode_Not_Attempted,
      "not-attempted data decode maps to image decode");
   Assert
     (Graphics.Image_Decode_Status (Graphics.Decode_Ok) =
      Terminal.App.Render_Model.Image_Decode_Ok,
      "ok data decode maps to image decode");
   Assert
     (Graphics.Image_Decode_Status (Graphics.Decode_Invalid_Byte) =
      Terminal.App.Render_Model.Image_Decode_Invalid_Byte,
      "invalid-byte data decode maps to image decode");
   Assert
     (Graphics.Image_Decode_Status (Graphics.Decode_Trailing_Data) =
      Terminal.App.Render_Model.Image_Decode_Trailing_Data,
      "trailing-data data decode maps to image decode");
   Assert
     (Graphics.Image_Decode_Status (Graphics.Decode_Preview_Truncated) =
      Terminal.App.Render_Model.Image_Decode_Preview_Truncated,
      "truncated data decode maps to image decode");
   Assert
     (Graphics.Image_Decode_Status (Graphics.Decode_Invalid_Data) =
      Terminal.App.Render_Model.Image_Decode_Invalid_Data,
      "invalid data maps to image decode");
   Assert
     (Graphics.Image_Decode_Status (Graphics.Decode_Too_Large) =
      Terminal.App.Render_Model.Image_Decode_Too_Large,
      "too-large data maps to image decode");
   Assert
     (Graphics.Image_Decode_Status (Graphics.Decode_Allocation_Failed) =
      Terminal.App.Render_Model.Image_Decode_Allocation_Failed,
      "allocation failure maps to image decode");
   Assert
     (Graphics.Image_Decode_Status (Graphics.Decode_Unsupported_Format) =
      Terminal.App.Render_Model.Image_Decode_Unsupported_Format,
      "unsupported-format data decode maps to image decode");

   declare
      Shared : aliased Terminal.Common.Bytes.Byte_Array := (1 => 16#A5#);
      Image : RM.Image_Command :=
        (Decoded_Byte_Length => 1,
         Decoded_Bytes => Shared'Unchecked_Access,
         Encoded_Source_Bytes => Shared'Unchecked_Access,
         Encoded_Source_Length => 1,
         Decoded_Preview_Length => 1,
         Decoded_Preview_Bytes => Shared'Unchecked_Access,
         others => <>);
      Copy : constant RM.Image_Command := Image;
   begin
      Assert
        (Copy.Decoded_Bytes = Image.Decoded_Bytes
         and then Copy.Encoded_Source_Bytes = Image.Encoded_Source_Bytes
         and then Copy.Decoded_Preview_Bytes = Image.Decoded_Preview_Bytes,
         "image commands are safely copyable borrowed views");
   end;

   declare
      Tight_RGBA : aliased Terminal.Common.Bytes.Byte_Array :=
        (1 => 16#11#, 2 => 16#22#, 3 => 16#33#, 4 => 16#44#,
         5 => 16#55#, 6 => 16#66#, 7 => 16#77#, 8 => 16#88#);
      Strided_RGB : aliased Terminal.Common.Bytes.Byte_Array :=
        (1 => 16#10#, 2 => 16#20#, 3 => 16#30#,
         4 => 16#EE#, 5 => 16#EE#,
         6 => 16#40#, 7 => 16#50#, 8 => 16#60#);
      Too_Short : aliased Terminal.Common.Bytes.Byte_Array :=
        (1 => 16#AA#, 2 => 16#BB#, 3 => 16#CC#);
      Image : RM.Image_Command :=
        (Raw_Format => 32,
         Pixel_Width => 1,
         Pixel_Height => 2,
         Decoded_Byte_Length => Tight_RGBA'Length,
         Decoded_Row_Stride_Bytes => 0,
         Decoded_Source => RM.Image_Decoded_Source_Buffer,
         Decoded_Bytes => Tight_RGBA'Unchecked_Access,
         others => <>);
   begin
      Assert
        (RM.Image_Decoded_Source_Bytes (Image) = 8,
         "tight RGBA image source extent");
      Assert
        (RM.Image_Decoded_Source_Available (Image),
         "tight RGBA image source available");
      Assert
        (RM.Image_Decoded_Row_Byte (Image, 0, 0) = 16#11#
         and then RM.Image_Decoded_Row_Byte (Image, 1, 3) = 16#88#,
         "tight RGBA row source bytes");
      Assert
        (RM.Image_Decoded_Row_Byte (Image, 2, 0) = 0
         and then RM.Image_Decoded_Row_Byte (Image, 1, 4) = 0,
         "tight RGBA row source bounds");

      Image.Raw_Format := 24;
      Image.Pixel_Width := 1;
      Image.Pixel_Height := 2;
      Image.Decoded_Byte_Length := Strided_RGB'Length;
      Image.Decoded_Row_Stride_Bytes := 5;
      Image.Decoded_Bytes := Strided_RGB'Unchecked_Access;
      Assert
        (RM.Image_Decoded_Source_Bytes (Image) = 8,
         "strided RGB image source extent");
      Assert
        (RM.Image_Decoded_Source_Available (Image),
         "strided RGB image source available");
      Assert
        (RM.Image_Decoded_Row_Byte (Image, 0, 4) = 16#EE#
         and then RM.Image_Decoded_Row_Byte (Image, 1, 2) = 16#60#,
         "strided RGB row source bytes");

      Image.Decoded_Source := RM.Image_Decoded_Source_None;
      Assert
        (RM.Image_Decoded_Source_Bytes (Image) = 0
         and then not RM.Image_Decoded_Source_Available (Image)
         and then RM.Image_Decoded_Row_Byte (Image, 0, 0) = 0,
         "missing decoded source should be unavailable");

      Image.Decoded_Source := RM.Image_Decoded_Source_Buffer;
      Image.Decoded_Byte_Length := Too_Short'Length;
      Image.Decoded_Bytes := Too_Short'Unchecked_Access;
      Assert
        (not RM.Image_Decoded_Source_Available (Image),
         "short decoded buffer should be unavailable");

      Image.Pixel_Width := RM.Max_Image_Decoded_Data_Length;
      Image.Pixel_Height := RM.Max_Image_Decoded_Data_Length;
      Image.Decoded_Byte_Length := 0;
      Image.Decoded_Row_Stride_Bytes := 0;
      Image.Decoded_Bytes := null;
      Assert
        (RM.Image_Decoded_Source_Bytes (Image) = 0,
         "oversized decoded metadata should not overflow");
   end;

   Assert
     (Graphics.Capability_Status_Label (Graphics.Sixel) =
      "sixel decode support; renderer availability unknown",
      "sixel capability status label");
   Assert
     (Graphics.Capability_Status_Label (Graphics.Kitty) =
      "kitty RGB/RGBA/indexed/PNG/JPEG/GIF decode support",
      "kitty capability status label");
   Assert
     (Graphics.Capability_Status_Label (Graphics.ITerm2) =
      "iTerm2 PNG/JPEG/GIF/PICT decode support",
      "iTerm2 capability status label");
   Assert
     (Graphics.Capability_Status_Label
        (Graphics.Kitty, Rendering_Available => True) =
      "kitty RGB/RGBA/indexed/PNG/JPEG/GIF rendering available",
      "kitty runtime capability status label");
   Assert
     (Graphics.Capability_Status_Label (Graphics.ITerm2)'Length <=
      Graphics.Max_Status_Label_Length,
      "graphics capability status labels should be bounded");

   Assert
     (Graphics.Name (Terminal.Core.No_Graphics) = "",
      "no graphics diagnostic name");
   Assert
     (Graphics.Name (Terminal.Core.Sixel_Graphics) = "sixel",
      "sixel diagnostic name");
   Assert
     (Graphics.Name (Terminal.Core.Kitty_Graphics) = "kitty",
      "kitty diagnostic name");
   Assert
     (Graphics.Name (Terminal.Core.ITerm2_Graphics) = "iTerm2",
      "iTerm2 diagnostic name");

   declare
      Diagnostics : constant Terminal.Core.Diagnostic_Snapshot :=
        (others => <>);
   begin
      Assert
        (Graphics.Graphics_Status_Label (Diagnostics) = "",
         "empty received graphics status label");
   end;

   Assert_Graphics_Label
     (Terminal.Core.Sixel_Graphics,
      7,
      "Received sixel graphics payload (7 bytes)",
      "sixel received graphics status label");
   Assert_Graphics_Label
     (Terminal.Core.Kitty_Graphics,
      16,
      "Received kitty graphics payload (16 bytes)",
      "kitty received graphics status label");
   Assert_Graphics_Label
     (Terminal.Core.ITerm2_Graphics,
      25,
      "Received iTerm2 image payload (25 bytes)",
      "iTerm2 received graphics status label");

   declare
      Data : Graphics.Graphics_Data_Preview;
      Target : Graphics.Graphics_Data_Preview;
      Initial_Owner : Terminal.App.Owned_Image_Data.Owner;
   begin
      Terminal.App.Owned_Image_Data.Allocate (Initial_Owner, 2);
      Terminal.App.Owned_Image_Data.Copy
        (Initial_Owner, (1 => 16#A5#, 2 => 16#5A#));
      Graphics.Adopt_Bytes (Data, Initial_Owner);
      Assert
        (Terminal.App.Owned_Image_Data.Is_Empty (Initial_Owner)
         and then not Graphics.Has_Bytes (Data),
         "adopting graphics bytes transfers their ownership");
      Graphics.Record_External_Decode
        (Data,
         Encoded_Length           => 4,
         Raw_Format               => 8,
         Pixel_Width              => 1,
         Pixel_Height             => 1,
         Decoded_Length           => 1,
         Decoded_Row_Stride_Bytes => 1,
         Status                   => Graphics.Decode_Ok);
      Graphics.Move (Data, Data);
      Assert
        (Graphics.Has_Bytes (Data) and then Data.Decode_Complete,
         "self move preserves graphics data");
      Graphics.Move (Data, Target);
      Assert
        (not Graphics.Has_Bytes (Data)
         and then not Data.Header_Recognized
         and then not Data.Decode_Complete
         and then Data.Decode_Status = Graphics.Decode_Not_Attempted
         and then Graphics.Has_Bytes (Target)
         and then Target.Decode_Complete,
         "graphics move resets its source and transfers its target");
      declare
         Detached : Terminal.App.Owned_Image_Data.Owner;
      begin
         Graphics.Take_Bytes (Target, Detached);
         Assert
           (not Terminal.App.Owned_Image_Data.Is_Empty (Detached)
            and then not Graphics.Has_Bytes (Target),
            "taking graphics bytes records detached ownership explicitly");
         Graphics.Adopt_Bytes (Target, Detached);
         Assert
           (Terminal.App.Owned_Image_Data.Is_Empty (Detached),
            "readopting graphics bytes restores owned storage state");
      end;
      Graphics.Set_Decode_Failure (Target, Graphics.Decode_Invalid_Byte);
      declare
         Hidden : Terminal.App.Owned_Image_Data.Owner;
      begin
         Graphics.Take_Bytes (Target, Hidden);
         Assert
           (not Graphics.Has_Bytes (Target)
            and then Terminal.App.Owned_Image_Data.Is_Empty (Hidden),
            "failed metadata hides and retains reusable owned storage");
      end;
      Graphics.Release (Target);
      Assert
        (not Graphics.Has_Bytes (Target)
         and then not Target.Header_Recognized
         and then not Target.Has_Data
         and then Target.Encoded_Length = 0
         and then Target.Raw_Format = 0
         and then Target.Pixel_Width = 0
         and then Target.Pixel_Height = 0
         and then Target.Decoded_Length = 0
         and then Target.Decoded_Row_Stride_Bytes = 0
         and then not Target.Decode_Complete
         and then Target.Decode_Status = Graphics.Decode_Not_Attempted,
         "graphics release resets storage and metadata");
   end;

   declare
      Data : Graphics.Graphics_Data_Preview;
      Owner : Terminal.App.Owned_Image_Data.Owner;
      Occupied : Terminal.App.Owned_Image_Data.Owner;
      Rejected : Boolean := False;
   begin
      Terminal.App.Owned_Image_Data.Allocate (Owner, 4);
      Terminal.App.Owned_Image_Data.Copy
        (Owner, (1 => 1, 2 => 2, 3 => 3, 4 => 4));
      Graphics.Adopt_Bytes (Data, Owner);
      Graphics.Record_External_Decode
        (Data,
         Encoded_Length           => 4,
         Raw_Format               => 32,
         Pixel_Width              => 1,
         Pixel_Height             => 1,
         Decoded_Length           => 4,
         Decoded_Row_Stride_Bytes => 4,
         Status                   => Graphics.Decode_Ok);
      begin
         Terminal.App.Owned_Image_Data.Allocate (Occupied, 1);
         Terminal.App.Owned_Image_Data.Replace_Element (Occupied, 1, 5);
         Graphics.Take_Bytes (Data, Occupied);
      exception
         when Program_Error =>
            Rejected := True;
      end;
      Assert
        (Rejected
         and then not Terminal.App.Owned_Image_Data.Is_Empty (Occupied)
         and then Graphics.Has_Bytes (Data),
         "graphics storage rejects a populated transfer target");
   end;

   declare
      Metadata_Only : Graphics.Graphics_Data_Preview;
   begin
      Graphics.Record_External_Decode
        (Metadata_Only,
         Encoded_Length           => 4,
         Raw_Format               => 32,
         Pixel_Width              => 1,
         Pixel_Height             => 1,
         Decoded_Length           => 4,
         Decoded_Row_Stride_Bytes => 4,
         Status                   => Graphics.Decode_Ok);
      Assert
        (not Graphics.Has_Bytes (Metadata_Only)
         and then Metadata_Only.Decode_Complete,
         "external decode metadata does not claim owned bytes");
   end;

   Run_Decoding_Matrix;
end Graphics_Capabilities_Smoke;
