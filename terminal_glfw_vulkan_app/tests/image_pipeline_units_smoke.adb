with Ada.Unchecked_Deallocation;
with AUnit.Assertions;
with Interfaces;

with Terminal.App.Image_Decode;
with Terminal.App.Graphics;
with Terminal.App.Graphics_Transport;
with Terminal.App.Image_Ingestion;
with Terminal.App.Image_Media;
with Terminal.App.Image_Rendering;
with Terminal.App.Image_Staging;
with Terminal.App.Image_Upload_Layout;
with Terminal.App.Render_Model;
with Terminal.App.Renderer;
with Terminal.App.Size_Arithmetic;
with Terminal.App.Vulkan_Retirement;
with Terminal.App.Image_Store;
with Terminal.App.Image_Store.Testing;
with Terminal.Common.Bytes;
with Terminal.Core;

procedure Image_Pipeline_Units_Smoke is
   use AUnit.Assertions;
   use type Terminal.App.Render_Model.Image_Data_Access;
   use type Terminal.Common.Bytes.Byte_Array;
   use type Terminal.App.Image_Staging.Decode_Status;
   use type Terminal.App.Graphics.Data_Decode_Status;
   use type Terminal.App.Image_Upload_Layout.Layout_Status;
   use type Terminal.Core.Kitty_Graphics_Result_Code;
   use type Interfaces.Unsigned_64;
   use type Terminal.App.Vulkan_Retirement.Retirement_Outcome;

   package Ingestion renames Terminal.App.Image_Ingestion;
   package Rendering renames Terminal.App.Image_Rendering;

   procedure Free is new Ada.Unchecked_Deallocation
     (Terminal.Common.Bytes.Byte_Array,
      Terminal.App.Render_Model.Image_Data_Access);

   Control : Terminal.App.Image_Store.Allocation_Control;
   Copy : Terminal.App.Render_Model.Image_Data_Access;

   function Exploding_Chunk (Index : Positive) return String is
     (raise Program_Error with Positive'Image (Index));

   procedure Ignore_Row
     (Y        : Natural;
      Row      : Terminal.Common.Bytes.Byte_Array;
      Continue : in out Boolean)
   is
      pragma Unreferenced (Y, Row);
   begin
      Continue := False;
   end Ignore_Row;
begin
   declare
      Result : Natural;
   begin
      Assert
        (Terminal.App.Size_Arithmetic.Try_Add
           (Natural'Last - 1, 1, Result)
         and then Result = Natural'Last,
         "checked addition accepts the representable boundary");
      Assert
        (not Terminal.App.Size_Arithmetic.Try_Add
           (Natural'Last, 1, Result)
         and then Result = 0,
         "checked addition rejects overflow deterministically");
      Assert
        (Terminal.App.Size_Arithmetic.Try_Multiply
           (Natural'Last, 1, Result)
         and then Result = Natural'Last,
         "checked multiplication accepts the representable boundary");
      Assert
        (not Terminal.App.Size_Arithmetic.Try_Multiply
           (Natural'Last, 2, Result)
         and then Result = 0,
         "checked multiplication rejects overflow deterministically");
   end;

   Assert
     (Terminal.App.Vulkan_Retirement.Evaluate
        (Terminal.App.Vulkan_Retirement.Fence_Ready,
         Cleanup_Succeeded => False) =
        Terminal.App.Vulkan_Retirement.Cleanup_Failed,
      "failed deferred cleanup cannot report successful retirement");
   Assert
     (Terminal.App.Vulkan_Retirement.Evaluate
        (Terminal.App.Vulkan_Retirement.Fence_Device_Lost,
         Cleanup_Succeeded => False) =
        Terminal.App.Vulkan_Retirement.Device_Lost,
      "device loss remains the primary retirement failure");

   declare
      Layout : Terminal.App.Image_Upload_Layout.Layout;
      Status : Terminal.App.Image_Upload_Layout.Layout_Status;
   begin
      Terminal.App.Image_Upload_Layout.Calculate
        (Width                  => 1,
         Height                 => 2,
         Source_Bytes_Per_Pixel => 4,
         Row_Stride_Bytes       => 8,
         Source_Bytes           => 12,
         Maximum_Bytes          => 64,
         Result                 => Layout,
         Status                 => Status);
      Assert
        (Status = Terminal.App.Image_Upload_Layout.Layout_Ok
         and then Layout.Required_Source_Bytes = 12
         and then Layout.Upload_Bytes = 8
         and then Layout.Staging_Bytes = 12
         and then Layout.Vulkan_Buffer_Row_Pixels = 2,
         "upload layout preserves padded rows without padding past the end");
      Terminal.App.Image_Upload_Layout.Calculate
        (Width                  => 1,
         Height                 => 2,
         Source_Bytes_Per_Pixel => 4,
         Row_Stride_Bytes       => 8,
         Source_Bytes           => 11,
         Maximum_Bytes          => 64,
         Result                 => Layout,
         Status                 => Status);
      Assert
        (Status = Terminal.App.Image_Upload_Layout.Invalid_Layout,
         "upload layout rejects truncated padded source data");
   end;
   declare
      Compressed : constant Terminal.Common.Bytes.Byte_Array :=
        (120, 156, 99, 96, 96, 96, 0, 0, 0, 4, 0, 1);
      Inflated : Terminal.App.Render_Model.Image_Data_Access := null;
      Length : Natural := 0;
      Status : Terminal.App.Graphics.Data_Decode_Status;
   begin
      Terminal.App.Graphics.Decode_Zlib_Data
        (Compressed, Compressed'Length, 4, True,
         Inflated, Length, Status);
      Assert
        (Status = Terminal.App.Graphics.Decode_Ok
         and then Length = 4
         and then Inflated /= null
         and then Inflated.all = (0, 0, 0, 0),
         "direct zlib decoding is bounded and preserves bytes");
      Free (Inflated);
      Terminal.App.Graphics.Decode_Zlib_Data
        (Compressed, Compressed'Length, 3, True,
         Inflated, Length, Status);
      Assert
        (Status = Terminal.App.Graphics.Decode_Too_Large
         and then Inflated = null,
         "direct zlib decoding rejects output beyond its limit");
   end;

   declare
      Encoded : Terminal.App.Render_Model.Image_Data_Access :=
        new Terminal.Common.Bytes.Byte_Array'
          (1 => Character'Pos ('A'),
           2 => Character'Pos ('Q'),
           3 => Character'Pos ('I'),
           4 => Character'Pos ('D'));
      Source : Terminal.App.Render_Model.Image_Command :=
        (Raw_Format => 24,
         Pixel_Width => 1,
         Pixel_Height => 1,
         Decoded_Row_Stride_Bytes => 3,
         Decoded_Source =>
           Terminal.App.Render_Model.Image_Decoded_Source_Raw_Base64,
         Encoded_Source_Bytes =>
           Terminal.App.Render_Model.Read_Only (Encoded),
         Encoded_Source_Length => 4,
         others => <>);
      Output : array (Positive range 1 .. 4) of Interfaces.Unsigned_8 :=
        (others => 0);
      Status : Terminal.App.Image_Staging.Decode_Status;
      Writes : Natural := 0;
      Stop_After_First : Boolean := False;

      procedure Write
        (Index    : Positive;
         Value    : Interfaces.Unsigned_8;
         Continue : in out Boolean) is
      begin
         Writes := Writes + 1;
         if Index > Output'Last then
            Continue := False;
         else
            Output (Index) := Value;
         end if;
         if Stop_After_First then
            Continue := False;
         end if;
      end Write;
   begin
      Terminal.App.Image_Staging.Decode_Encoded_RGBA
        (Source, Output'Length, Write'Access, Status);
      Assert
        (Status = Terminal.App.Image_Staging.Decode_Ok
         and then Output = (1, 2, 3, 255),
         "encoded staging expands RGB directly to RGBA");
      Writes := 0;
      Stop_After_First := True;
      Terminal.App.Image_Staging.Decode_Encoded_RGBA
        (Source, Output'Length, Write'Access, Status);
      Assert
        (Status = Terminal.App.Image_Staging.Invalid_Source
         and then Writes = 1,
         "RGB staging stops immediately when its sink declines a byte");
      Stop_After_First := False;
      Source.Encoded_Source_Length := Natural'Last;
      Terminal.App.Image_Staging.Decode_Encoded_RGBA
        (Source, Output'Length, Write'Access, Status);
      Assert
        (Status = Terminal.App.Image_Staging.Invalid_Source,
         "encoded staging rejects inconsistent lengths before allocation");
      Free (Encoded);
      Source.Encoded_Source_Bytes := null;
   end;

   declare
      Encoded : Terminal.App.Render_Model.Image_Data_Access :=
        new Terminal.Common.Bytes.Byte_Array'
          (1 => Character'Pos ('A'),
           2 => Character'Pos ('Q'),
           3 => Character'Pos ('I'),
           4 => Character'Pos ('D'),
           5 => Character'Pos ('B'),
           6 => Character'Pos ('A'),
           7 => Character'Pos ('U'),
           8 => Character'Pos ('G'),
           9 => Character'Pos ('B'),
           10 => Character'Pos ('w'),
           11 => Character'Pos ('g'),
           12 => Character'Pos ('='));
      Source : Terminal.App.Render_Model.Image_Command :=
        (Raw_Format => 32,
         Pixel_Width => 1,
         Pixel_Height => 2,
         Decoded_Row_Stride_Bytes => 8,
         Decoded_Source =>
           Terminal.App.Render_Model.Image_Decoded_Source_Raw_Base64,
         Encoded_Source_Bytes =>
           Terminal.App.Render_Model.Read_Only (Encoded),
         Encoded_Source_Length => 12,
         others => <>);
      Output : array (Positive range 1 .. 12) of Interfaces.Unsigned_8 :=
        (others => 16#AA#);
      Status : Terminal.App.Image_Staging.Decode_Status;

      procedure Write
        (Index    : Positive;
         Value    : Interfaces.Unsigned_8;
         Continue : in out Boolean) is
      begin
         if Index > Output'Last then
            Continue := False;
         else
            Output (Index) := Value;
         end if;
      end Write;
   begin
      Terminal.App.Image_Staging.Decode_Encoded_RGBA
        (Source, Output'Length, Write'Access, Status);
      Assert
        (Status = Terminal.App.Image_Staging.Decode_Ok
         and then Output = (1, 2, 3, 4, 0, 0, 0, 0, 5, 6, 7, 8),
         "padded RGBA staging writes only the allocated final-row extent");
      Free (Encoded);
      Source.Encoded_Source_Bytes := null;
   end;

   declare
      Diagnostics : Terminal.App.Renderer.Renderer_Diagnostics :=
        (Last_Image_Count => 1,
         Last_Image_Pixel_Width => Natural'Last,
         Last_Image_Pixel_Height => Natural'Last,
         Last_Image_Payload_Length => Natural'Last,
         Last_Image_Decoded_Preview_Length =>
           Terminal.App.Render_Model.Max_Image_Decoded_Preview_Length,
         Last_Image_Encoded_Preview_Length => Natural'Last,
         Last_Image_Decoded_Preview_Bytes => (others => 16#FF#),
         others => <>);
   begin
      Assert
        (Terminal.App.Renderer.Image_Status_Label (Diagnostics)'Length <=
           Terminal.App.Renderer.Max_Status_Label_Length,
         "renderer image status labels are bounded");
      Assert
        (Terminal.App.Renderer.Media_Status_Label (Diagnostics)'Length <=
           Terminal.App.Renderer.Max_Status_Label_Length,
         "renderer media status labels are bounded");
   end;

   Assert
     (Rendering.Animation_Capacity_Available
        (Retained => 2, Incoming => 2, Limit => 4),
      "animation capacity accepts an in-limit append");
   Assert
     (not Rendering.Animation_Capacity_Available
        (Retained => 2, Incoming => 2, Limit => 1),
      "animation capacity rejects a full store without underflow");
   Assert
     (not Rendering.Animation_Capacity_Available
        (Retained => 0, Incoming => 0, Limit => 4),
      "animation capacity rejects an empty image");

   Assert
     (Ingestion.Payload_Start (Ingestion.Kitty, "a=T;AAAA") = 5,
      "Kitty payload boundary");
   Assert
     (Ingestion.Payload_Start (Ingestion.ITerm2, "File=x:AAAA") = 8,
      "iTerm2 payload boundary");
   Assert
     (Ingestion.Payload_Start (Ingestion.Kitty, "a=T;") = 0,
      "empty payload is rejected");
   declare
      Header : Terminal.App.Graphics.Graphics_Header := (others => <>);
      Size : Ingestion.Pixel_Size;
   begin
      Header.ITerm2_Width_Specified := True;
      Header.ITerm2_Width_Value := 10;
      Header.ITerm2_Width_Unit := Terminal.App.Graphics.ITerm2_Cells;
      Header.ITerm2_Height_Specified := False;
      Header.ITerm2_Preserve_Aspect_Ratio := True;
      Size := Ingestion.ITerm2_Render_Size
        (Header, 20, 10, 8, 16, 800, 600);
      Assert
        (Size.Width = 80.0 and then Size.Height = 40.0,
         "iTerm2 sizing preserves aspect ratio outside the renderer");
   end;
   declare
      Raw_Text : constant String := "Gf=32,s=1,v=1;AAAAAA==";
      Raw_Header : constant Terminal.App.Graphics.Graphics_Header :=
        Terminal.App.Graphics.Header_Text
          (Terminal.Core.Kitty_Graphics, Raw_Text);
      Compressed_Text : constant String :=
        "Gf=32,s=1,v=1,o=z;eJxjYGBgAAAABAAB";
      Compressed_Header : constant Terminal.App.Graphics.Graphics_Header :=
        Terminal.App.Graphics.Header_Text
          (Terminal.Core.Kitty_Graphics, Compressed_Text);
      Mismatched_Text : constant String :=
        "Gf=1001,s=1,v=1,S=12,o=z;eJxjYGBgAAAABAAB";
      Mismatched_Header : constant Terminal.App.Graphics.Graphics_Header :=
        Terminal.App.Graphics.Header_Text
          (Terminal.Core.Kitty_Graphics, Mismatched_Text);
      Mismatched_GIF_Text : constant String :=
        "Gf=1002,s=1,v=1,S=12,o=z;eJxjYGBgAAAABAAB";
      Mismatched_GIF_Header : constant Terminal.App.Graphics.Graphics_Header :=
        Terminal.App.Graphics.Header_Text
          (Terminal.Core.Kitty_Graphics, Mismatched_GIF_Text);
      Zero_Size_Text : constant String := "Gf=32,s=0,v=1;AAAAAA==";
      Zero_Size_Header : constant Terminal.App.Graphics.Graphics_Header :=
        Terminal.App.Graphics.Header_Text
          (Terminal.Core.Kitty_Graphics, Zero_Size_Text);
   begin
      declare
         Raw_Result : constant Terminal.Core.Kitty_Graphics_Result_Code :=
           Ingestion.Validate_Kitty_Query
             (Raw_Header,
              Raw_Text,
              Terminal.App.Graphics_Transport.Default_Access_Policy,
              Maximum_Bytes => 3);
         Compressed_Result : constant
           Terminal.Core.Kitty_Graphics_Result_Code :=
             Ingestion.Validate_Kitty_Query
               (Compressed_Header,
                Compressed_Text,
                Terminal.App.Graphics_Transport.Default_Access_Policy,
                Maximum_Bytes => 3);
      begin
      Assert
        (Raw_Result = Terminal.Core.Kitty_ENOMEM,
         "Kitty query validation enforces the direct decoded-byte limit");
      Assert
        (Compressed_Result = Terminal.Core.Kitty_ENOMEM,
         "Kitty query validation enforces the streamed decoded-byte limit");
      Assert
        (Ingestion.Validate_Kitty_Query
           (Raw_Header,
            Raw_Text,
            Terminal.App.Graphics_Transport.Default_Access_Policy,
            Maximum_Bytes => 4) = Terminal.Core.Kitty_OK,
         "Kitty query validation accepts direct data at the byte limit");
      Assert
        (Ingestion.Validate_Kitty_Query
           (Compressed_Header,
            Compressed_Text,
            Terminal.App.Graphics_Transport.Default_Access_Policy,
            Maximum_Bytes => 4) = Terminal.Core.Kitty_OK,
         "Kitty query validation accepts streamed data at the byte limit");
      Assert
        (Ingestion.Validate_Kitty_Query
           (Mismatched_Header,
            Mismatched_Text,
            Terminal.App.Graphics_Transport.Default_Access_Policy,
            Maximum_Bytes => 64) = Terminal.Core.Kitty_EINVAL,
         "compressed direct data must match its declared media format");
      Assert
        (Ingestion.Validate_Kitty_Query
           (Mismatched_GIF_Header,
            Mismatched_GIF_Text,
            Terminal.App.Graphics_Transport.Default_Access_Policy,
            Maximum_Bytes => 64) = Terminal.Core.Kitty_EINVAL,
         "compressed direct data cannot masquerade as GIF");
      Assert
        (Ingestion.Validate_Kitty_Query
           (Zero_Size_Header,
            Zero_Size_Text,
            Terminal.App.Graphics_Transport.Default_Access_Policy,
            Maximum_Bytes => 64) = Terminal.Core.Kitty_EINVAL,
         "invalid raw geometry is not reported as resource exhaustion");
      end;
   end;
   declare
      Bytes : Terminal.App.Graphics_Transport.Byte_Array_Access :=
        new Terminal.Common.Bytes.Byte_Array'(1, 2, 3);
   begin
      Assert
        (Ingestion.Encode_Base64 (Bytes, Bytes'Length) = "AQID",
         "ingestion encodes local-media payloads");
      Assert
        (Ingestion.Encode_Base64 (Bytes, 1) = "AQ=="
         and then Ingestion.Encode_Base64 (Bytes, 2) = "AQI=",
         "ingestion pads partial Base64 blocks");
      Terminal.App.Graphics_Transport.Release (Bytes);
   end;

   Terminal.App.Image_Store.Testing.Fail_Allocation_After (Control, 1);
   Copy := Ingestion.Copy_Text ("payload", Control);
   Assert (Copy = null, "allocation seam rejects the selected attempt");
   Copy := Ingestion.Copy_Text ("payload", Control);
   Assert
     (Copy /= null and then Copy'Length = 7,
      "allocation seam automatically disarms");
   Free (Copy);

   declare
      Data : Terminal.App.Graphics.Graphics_Data_Preview;
      Encoded_Length : Natural;
      Propagated : Boolean := False;
   begin
      begin
         Terminal.App.Graphics.Decode_Base64_Zlib_PNG_Chunk_Rows
           (Chunk_Count => 1,
            Chunk_Text => Exploding_Chunk'Access,
            Inflated_Length => 1,
            Encoded_Length => Encoded_Length,
            Row_Sink => Ignore_Row'Access,
            Result => Data);
      exception
         when Program_Error =>
            Propagated := True;
      end;
      Assert
        (Propagated,
         "unexpected decoder exceptions propagate after cleanup");
   end;

   declare
      Diagnostics : Rendering.Media_Diagnostics :=
        (Attempted => True,
         Status => Terminal.App.Image_Decode.Decode_Invalid_Data,
         Error =>
           (Present => True,
            Identifier_Length =>
              Terminal.App.Image_Media.Max_Diagnostic_Identifier_Length,
            Identifier => (others => 'x'),
            Source_Offset => Interfaces.Unsigned_64'Last,
            Expected => Interfaces.Unsigned_64'Last,
            Actual => Interfaces.Unsigned_64'Last,
            others => <>),
         Adapter_Buffer_Bytes => Natural'Last,
         Decoder_Configured_Bytes => Natural'Last,
         Warning_Count => Natural'Last,
         First_Warning =>
           (Present => True,
            Identifier_Length => 1,
            Identifier => (1 => 'w', others => ASCII.NUL),
            others => <>));
   begin
      Assert
        (Rendering.Status_Label (Diagnostics)'Length =
           Rendering.Max_Status_Label_Length,
         "media status labels are bounded");
      Rendering.Set_Status
        (Diagnostics, Terminal.App.Image_Decode.Decode_Allocation_Failed);
      Assert
        (not Diagnostics.Error.Present
         and then Diagnostics.Warning_Count = 0
         and then not Diagnostics.First_Warning.Present
         and then Diagnostics.Adapter_Buffer_Bytes = 0
         and then Diagnostics.Decoder_Configured_Bytes = 0
         and then Rendering.Status_Label (Diagnostics) =
           "media allocation-failed",
         "status replacement clears stale structured diagnostics");
   end;
end Image_Pipeline_Units_Smoke;
