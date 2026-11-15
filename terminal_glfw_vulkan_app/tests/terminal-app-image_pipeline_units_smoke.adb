with Terminal.App.Image_Data;
with Terminal.App.Owned_Image_Data.Unsafe;
with System;
with Ada.Unchecked_Deallocation;
with Ada.Exceptions;
with Ada.Streams;
with AUnit.Assertions;
with Interfaces;
with Terminal.App.Graphics.Decoder_Testing;

with Terminal.App.Inflate_Filter;
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
with Terminal.App.Vulkan_Destroy_Once;
with Terminal.App.Vulkan_Destroy_Pair;
with Terminal.App.Vulkan_Destroy_Triple;
with Terminal.App.Vulkan_Unmap_Once;
with Terminal.App.Image_Store;
with Terminal.App.Image_Store.Testing;
with Terminal.App.Owned_Image_Data;
with Terminal.App.Shared_Image_Data;
with Terminal.Common.Bytes;
with Terminal.Core;

procedure Terminal.App.Image_Pipeline_Units_Smoke is
   use AUnit.Assertions;
   use type Terminal.Common.Bytes.Byte;
   use type Terminal.Common.Bytes.Byte_Array;
   use type Terminal.App.Image_Staging.Decode_Status;
   use type Terminal.App.Graphics.Data_Decode_Status;
   use type Terminal.App.Image_Upload_Layout.Layout_Status;
   use type Terminal.Core.Graphics_Completion_Code;
   use type Interfaces.Unsigned_64;
   use type Terminal.App.Vulkan_Retirement.Retirement_Outcome;
   use type Terminal.App.Vulkan_Retirement.Fence_Restore_Outcome;
   use type Terminal.App.Image_Data.Image_Data_Access;
   use type Terminal.App.Render_Model.Image_Data_View;
   use type System.Address;

   package Ingestion renames Terminal.App.Image_Ingestion;
   package Rendering renames Terminal.App.Image_Rendering;

   procedure Free is new Ada.Unchecked_Deallocation
     (Terminal.Common.Bytes.Byte_Array,
      Terminal.App.Image_Data.Image_Data_Access);

   Control : Terminal.App.Image_Store.Allocation_Control;
   Copy : Terminal.App.Owned_Image_Data.Owner;

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
      Bytes : aliased Terminal.Common.Bytes.Byte_Array :=
        (1 => 16#11#, 2 => 16#22#, 3 => 16#33#, 4 => 16#44#);
      Seed  : Terminal.App.Shared_Image_Data.Handle;
      Left  : aliased Terminal.App.Shared_Image_Data.Handle;
      Right : aliased Terminal.App.Shared_Image_Data.Handle;

      task type Releaser
        (Item : not null access Terminal.App.Shared_Image_Data.Handle);

      task body Releaser is
      begin
         Terminal.App.Shared_Image_Data.Reset (Item.all);
      end Releaser;
   begin
      Terminal.App.Shared_Image_Data.Set
        (Seed, Bytes'Unchecked_Access, Bytes'Length);
      Left := Seed;
      Right := Seed;
      declare
         Release_Left  : Releaser (Left'Access);
         Release_Right : Releaser (Right'Access);
      begin
         null;
      end;
      Assert
        (Terminal.App.Shared_Image_Data.View (Seed) /= null
         and then Terminal.App.Shared_Image_Data.View (Seed) (4) = 16#44#,
         "concurrent releases preserve the remaining shared image owner");
   end;

   declare
      Active : Boolean := True;
      Success : Boolean;
      Calls : Natural := 0;
      Failures : Natural := 0;

      procedure Exploding_Unmap is
      begin
         Calls := Calls + 1;
         raise Program_Error with "injected unmap failure";
      end Exploding_Unmap;

      procedure Record_Failure
        (Error : Ada.Exceptions.Exception_Occurrence) is
         pragma Unreferenced (Error);
      begin
         Failures := Failures + 1;
      end Record_Failure;
   begin
      Terminal.App.Vulkan_Unmap_Once.Run
        (Active, Exploding_Unmap'Access, Record_Failure'Access, Success);
      Assert
        (not Success and then not Active and then Calls = 1 and then Failures = 1,
         "unmap failure clears the retry marker before reporting");
      Terminal.App.Vulkan_Unmap_Once.Run
        (Active, Exploding_Unmap'Access, Record_Failure'Access, Success);
      Assert
        (Success and then Calls = 1 and then Failures = 1,
         "cleared unmap marker prevents a second foreign call");
   end;

   declare
      Data  : Terminal.App.Image_Data.Image_Data_Access :=
        new Terminal.Common.Bytes.Byte_Array'
          (7 => 11, 8 => 22, 9 => 33);
      Original_Address : constant System.Address := Data.all'Address;
      Taken : Terminal.App.Image_Data.Image_Data_Access;
      Owner : Terminal.App.Owned_Image_Data.Owner;
      Read_Called : Boolean := False;

      procedure Check_Data (Bytes : Terminal.Common.Bytes.Byte_Array) is
      begin
         Read_Called := True;
         Assert
           (Bytes'First = 7
            and then Bytes'Last = 9
            and then Bytes = (11, 22, 33),
            "owned reads preserve the adopted array bounds and bytes");
      end Check_Data;

      procedure Change_Data
        (Bytes : in out Terminal.Common.Bytes.Byte_Array) is
      begin
         Bytes (Bytes'First + 1) := 44;
      end Change_Data;
   begin
      Terminal.App.Owned_Image_Data.Unsafe.Adopt (Owner, Data);
      Assert
        (Data = null
         and then Terminal.App.Owned_Image_Data.Length (Owner) = 3
         and then Terminal.App.Owned_Image_Data.Element (Owner, 3) = 33,
         "adoption transfers ownership and uses relative element offsets");
      Terminal.App.Owned_Image_Data.Read (Owner, Check_Data'Access);
      Assert (Read_Called, "owned read invokes its scoped callback");
      Terminal.App.Owned_Image_Data.Modify (Owner, Change_Data'Access);
      Assert
        (Terminal.App.Owned_Image_Data.Element (Owner, 2) = 44,
         "owned modification remains scoped to its callback");
      Terminal.App.Owned_Image_Data.Unsafe.Take (Owner, Taken);
      Assert
        (Terminal.App.Owned_Image_Data.Is_Empty (Owner)
         and then Taken /= null
         and then Taken.all'Address = Original_Address
         and then Taken'First = 7
         and then Taken (8) = 44,
         "take transfers the allocation without changing its bounds");
      Free (Taken);
   end;

   declare
      State       : Terminal.App.Inflate_Filter.Decoder;
      Started     : Boolean;
      Translated  : Boolean;
      Input_Last  : Ada.Streams.Stream_Element_Offset;
      Output_Last : Ada.Streams.Stream_Element_Offset;
      Invalid     : constant Ada.Streams.Stream_Element_Array (1 .. 2) :=
        (16#FF#, 16#FF#);
      Output      : Ada.Streams.Stream_Element_Array (1 .. 8);
   begin
      Terminal.App.Inflate_Filter.Start
        (State, Terminal.App.Inflate_Filter.Zlib_Wrapper, Started);
      Assert (Started, "inflate filter starts from the closed state");
      Terminal.App.Inflate_Filter.Start
        (State, Terminal.App.Inflate_Filter.Raw_Deflate, Started);
      Assert (Started, "inflate filter can be restarted while active");
      Terminal.App.Inflate_Filter.Close (State);
      Terminal.App.Inflate_Filter.Close (State);
      Terminal.App.Inflate_Filter.Start
        (State, Terminal.App.Inflate_Filter.Zlib_Wrapper, Started);
      Assert (Started, "inflate filter can be reused after repeated close");
      Terminal.App.Inflate_Filter.Translate
        (State, Invalid, Input_Last, Output, Output_Last, Translated);
      Assert (not Translated, "invalid compressed input fails deterministically");
      Terminal.App.Inflate_Filter.Start
        (State, Terminal.App.Inflate_Filter.Zlib_Wrapper, Started);
      Assert (Started, "inflate filter can recover from a failed stream");
      Terminal.App.Inflate_Filter.Close (State);
   end;

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
   Assert
     (Terminal.App.Vulkan_Retirement.Classify_Fence_Restore
        (Succeeded => False, Device_Lost => True) =
        Terminal.App.Vulkan_Retirement.Fence_Restore_Device_Lost
      and then
        Terminal.App.Vulkan_Retirement.Classify_Fence_Restore
          (Succeeded => False, Device_Lost => False) =
          Terminal.App.Vulkan_Retirement.Fence_Restore_Failed
      and then
        Terminal.App.Vulkan_Retirement.Classify_Fence_Restore
          (Succeeded => True, Device_Lost => False) =
          Terminal.App.Vulkan_Retirement.Fence_Restored,
      "upload-fence restoration outcomes are classified deterministically");

   declare
      Null_Handle : constant Natural := 0;
      Handle : Natural := 17;
      Destroyed : Natural := 0;
      Reported : Boolean := False;
      Succeeded : Boolean;

      procedure Exploding_Destroy (Value : Natural) is
      begin
         Destroyed := Value;
         raise Program_Error with "simulated foreign destructor failure";
      end Exploding_Destroy;

      procedure Report_Failure
        (Occurrence : Ada.Exceptions.Exception_Occurrence) is
         pragma Unreferenced (Occurrence);
      begin
         Reported := True;
      end Report_Failure;

      procedure Destroy_Once is new Terminal.App.Vulkan_Destroy_Once
        (Natural, Null_Handle, Exploding_Destroy, Report_Failure);
   begin
      Destroy_Once (Handle, Succeeded);
      Assert
        (not Succeeded
         and then Reported
         and then Destroyed = 17
         and then Handle = Null_Handle,
         "a raising destructor is reported after clearing the owned handle");
      Reported := False;
      Destroy_Once (Handle, Succeeded);
      Assert
        (Succeeded and then not Reported and then Destroyed = 17,
         "destroying an already cleared handle is a successful no-op");
   end;

   declare
      First : Natural := 11;
      Second : Natural := 22;
      First_Calls : Natural := 0;
      Second_Calls : Natural := 0;
      Fail_First : Boolean := True;
      Fail_Second : Boolean := False;
      Succeeded : Boolean;

      procedure Destroy_First (Value : Natural) is
      begin
         First_Calls := First_Calls + 1;
         if Fail_First and then Value = 11 then
            raise Program_Error with "simulated child destructor failure";
         end if;
      end Destroy_First;

      procedure Destroy_Second (Value : Natural) is
      begin
         Second_Calls := Second_Calls + 1;
         if Fail_Second and then Value = 22 then
            raise Program_Error with "simulated parent destructor failure";
         end if;
      end Destroy_Second;

      procedure Destroy_Chain is new Terminal.App.Vulkan_Destroy_Pair
        (Natural, 0, "test child", Destroy_First,
         Natural, 0, "test parent", Destroy_Second);
   begin
      Destroy_Chain (First, Second, Succeeded);
      Assert
        (not Succeeded
         and then First = 0
         and then Second = 0
         and then First_Calls = 1
         and then Second_Calls = 0,
         "a failed child destroy quarantines its parent handle");

      First := 11;
      Second := 22;
      First_Calls := 0;
      Second_Calls := 0;
      Fail_First := False;
      Fail_Second := True;
      Destroy_Chain (First, Second, Succeeded);
      Assert
        (not Succeeded
         and then First = 0
         and then Second = 0
         and then First_Calls = 1
         and then Second_Calls = 1,
         "a failed parent destroy still clears both ownership markers");
   end;

   declare
      First : Natural := 11;
      Second : Natural := 22;
      Third : Natural := 33;
      First_Calls : Natural := 0;
      Second_Calls : Natural := 0;
      Third_Calls : Natural := 0;
      Fail_First : Boolean := True;
      Fail_Second : Boolean := False;
      Succeeded : Boolean;

      procedure Destroy_First (Value : Natural) is
      begin
         First_Calls := First_Calls + 1;
         if Fail_First and then Value = 11 then
            raise Program_Error with "simulated parent destroy failure";
         end if;
      end Destroy_First;

      procedure Destroy_Second (Value : Natural) is
      begin
         Second_Calls := Second_Calls + 1;
         if Fail_Second and then Value = 22 then
            raise Program_Error with "simulated middle destroy failure";
         end if;
      end Destroy_Second;

      procedure Destroy_Third (Value : Natural) is
         pragma Unreferenced (Value);
      begin
         Third_Calls := Third_Calls + 1;
      end Destroy_Third;

      procedure Destroy_Chain is new Terminal.App.Vulkan_Destroy_Triple
        (Natural, 0, "test first", Destroy_First,
         Natural, 0, "test second", Destroy_Second,
         Natural, 0, "test third", Destroy_Third);
   begin
      Destroy_Chain (First, Second, Third, Succeeded);
      Assert
        (not Succeeded
         and then First = 0
         and then Second = 0
         and then Third = 0
         and then First_Calls = 1
         and then Second_Calls = 0
         and then Third_Calls = 0,
         "a failed parent cleanup quarantines every dependent handle");

      First := 11;
      Second := 22;
      Third := 33;
      First_Calls := 0;
      Second_Calls := 0;
      Third_Calls := 0;
      Fail_First := False;
      Fail_Second := True;
      Destroy_Chain (First, Second, Third, Succeeded);
      Assert
        (not Succeeded
         and then First = 0
         and then Second = 0
         and then Third = 0
         and then First_Calls = 1
         and then Second_Calls = 1
         and then Third_Calls = 0,
         "a failed middle cleanup quarantines its dependent handle");
   end;

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
      Terminal.App.Image_Upload_Layout.Calculate
        (Width                  => 4,
         Height                 => 2,
         Source_Bytes_Per_Pixel => 1,
         Row_Stride_Bytes       => 4,
         Source_Bytes           => 8,
         Maximum_Bytes          => 64,
         Result                 => Layout,
         Status                 => Status,
         Target_Bytes_Per_Pixel => 1);
      Assert
        (Status = Terminal.App.Image_Upload_Layout.Layout_Ok
         and then Layout.Upload_Bytes = 8
         and then Layout.Staging_Bytes = 8,
         "upload layout takes a one-byte glyph atlas as it is");
   end;
   declare
      Compressed : constant Terminal.Common.Bytes.Byte_Array :=
        (120, 156, 99, 96, 96, 96, 0, 0, 0, 4, 0, 1);
      Inflated : Terminal.App.Owned_Image_Data.Owner;
      Length : Natural := 0;
      Status : Terminal.App.Graphics.Data_Decode_Status;
      Bytes_Match : Boolean := False;
      procedure Check_Bytes (Bytes : Terminal.Common.Bytes.Byte_Array) is
      begin
         Bytes_Match := Bytes = (0, 0, 0, 0);
      end Check_Bytes;
   begin
      Terminal.App.Graphics.Decoder_Testing.Decode_Zlib_Data
        (Compressed, Compressed'Length, 4, True,
         Inflated, Length, Status);
      Terminal.App.Owned_Image_Data.Read (Inflated, Check_Bytes'Access);
      Assert
        (Status = Terminal.App.Graphics.Decode_Ok
         and then Length = 4
         and then not Terminal.App.Owned_Image_Data.Is_Empty (Inflated)
         and then Bytes_Match,
         "direct zlib decoding is bounded and preserves bytes");
      Terminal.App.Graphics.Decoder_Testing.Decode_Zlib_Data
        (Compressed, Compressed'Length, 3, True,
         Inflated, Length, Status);
      Assert
        (Status = Terminal.App.Graphics.Decode_Too_Large
         and then Terminal.App.Owned_Image_Data.Is_Empty (Inflated),
         "direct zlib decoding rejects output beyond its limit");
      Terminal.App.Graphics.Decoder_Testing.Decode_Zlib_Data
        (Compressed, Compressed'Length + 1, 4, True,
         Inflated, Length, Status);
      Assert
        (Status = Terminal.App.Graphics.Decode_Invalid_Data
         and then Length = 0
         and then Terminal.App.Owned_Image_Data.Is_Empty (Inflated),
         "direct zlib decoding owns its input-length validation");
   end;

   declare
      Encoded : Terminal.App.Image_Data.Image_Data_Access :=
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
           Terminal.App.Image_Data.Read_Only (Encoded),
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
      Encoded : Terminal.App.Image_Data.Image_Data_Access :=
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
           Terminal.App.Image_Data.Read_Only (Encoded),
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
      Header : Terminal.App.Graphics.Graphics_Header :=
        (Protocol => Terminal.App.Graphics.ITerm2, others => <>);
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
      Wide_Raw_Text : constant String := "Gf=32,s=2,v=1;AAAAAAAAAAA=";
      Wide_Raw_Header : constant Terminal.App.Graphics.Graphics_Header :=
        Terminal.App.Graphics.Header_Text
          (Terminal.Core.Kitty_Graphics, Wide_Raw_Text);
      Animated_GIF_Text : constant String :=
        "Gf=1002;"
        & "R0lGODlhAQABAPAAAP8AAAAAACH/C05FVFNDQVBFMi4wAwEBAAAh+QQABQAAACwA"
        & "AAAAAQABAAACAkQBACH5BAAHAAAALAAAAAABAAEAgAAA/wAAAAICRAEAOw==";
      Animated_GIF_Header : constant Terminal.App.Graphics.Graphics_Header :=
        Terminal.App.Graphics.Header_Text
          (Terminal.Core.Kitty_Graphics, Animated_GIF_Text);
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
         Raw_Result : constant Terminal.Core.Graphics_Completion_Code :=
           Ingestion.Validate_Kitty_Query
             (Raw_Header,
              Raw_Text,
              Terminal.App.Graphics_Transport.Default_Access_Policy,
              Maximum_Bytes => 3);
         Compressed_Result : constant
           Terminal.Core.Graphics_Completion_Code :=
             Ingestion.Validate_Kitty_Query
               (Compressed_Header,
                Compressed_Text,
                Terminal.App.Graphics_Transport.Default_Access_Policy,
                Maximum_Bytes => 3);
      begin
      Assert
        (Raw_Result = Terminal.Core.Graphics_ENOMEM,
         "Kitty query validation enforces the direct decoded-byte limit");
      Assert
        (Compressed_Result = Terminal.Core.Graphics_ENOMEM,
         "Kitty query validation enforces the streamed decoded-byte limit");
      Assert
        (Ingestion.Validate_Kitty_Query
           (Raw_Header,
            Raw_Text,
            Terminal.App.Graphics_Transport.Default_Access_Policy,
            Maximum_Bytes => 4) = Terminal.Core.Graphics_OK,
         "Kitty query validation accepts direct data at the byte limit");
      Assert
        (Ingestion.Validate_Kitty_Query
           (Wide_Raw_Header,
            Wide_Raw_Text,
            Terminal.App.Graphics_Transport.Default_Access_Policy,
            Maximum_Bytes => 8,
            Maximum_Pixel_Dimension => 1) = Terminal.Core.Graphics_ENOMEM,
         "Kitty query validation enforces the configured dimension limit");
      Assert
        (Ingestion.Validate_Kitty_Query
           (Animated_GIF_Header,
            Animated_GIF_Text,
            Terminal.App.Graphics_Transport.Default_Access_Policy,
            Maximum_Bytes => 1_024,
            Maximum_Frames => 1) = Terminal.Core.Graphics_ENOMEM,
         "Kitty query validation enforces the configured animation limit");
      Assert
        (Ingestion.Validate_Kitty_Query
           (Compressed_Header,
            Compressed_Text,
            Terminal.App.Graphics_Transport.Default_Access_Policy,
            Maximum_Bytes => 4) = Terminal.Core.Graphics_OK,
         "Kitty query validation accepts streamed data at the byte limit");
      Assert
        (Ingestion.Validate_Kitty_Query
           (Mismatched_Header,
            Mismatched_Text,
            Terminal.App.Graphics_Transport.Default_Access_Policy,
            Maximum_Bytes => 64) = Terminal.Core.Graphics_EINVAL,
         "compressed direct data must match its declared media format");
      Assert
        (Ingestion.Validate_Kitty_Query
           (Mismatched_GIF_Header,
            Mismatched_GIF_Text,
            Terminal.App.Graphics_Transport.Default_Access_Policy,
            Maximum_Bytes => 64) = Terminal.Core.Graphics_EINVAL,
         "compressed direct data cannot masquerade as GIF");
      Assert
        (Ingestion.Validate_Kitty_Query
           (Zero_Size_Header,
            Zero_Size_Text,
            Terminal.App.Graphics_Transport.Default_Access_Policy,
            Maximum_Bytes => 64) = Terminal.Core.Graphics_EINVAL,
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
   declare
      Compact_Control : Terminal.App.Image_Store.Allocation_Control;
      Compact : Terminal.App.Owned_Image_Data.Owner;
   begin
      Ingestion.Copy_Compact_Base64
        (" A" & ASCII.CR & "QI" & ASCII.LF & "D ", Compact_Control,
         Compact);
      Assert
        (Compact.Length = 4
         and then Compact.Element (1) = Character'Pos ('A')
         and then Compact.Element (2) = Character'Pos ('Q')
         and then Compact.Element (3) = Character'Pos ('I')
         and then Compact.Element (4) = Character'Pos ('D'),
         "Base64 ingestion compacts accepted whitespace once");
      Compact.Release;
   end;

   Terminal.App.Image_Store.Testing.Fail_Allocation_After (Control, 1);
   Ingestion.Copy_Text ("payload", Control, Copy);
   Assert (Copy.Is_Empty, "allocation seam rejects the selected attempt");
   Ingestion.Copy_Text ("payload", Control, Copy);
   Assert
     (Copy.Length = 7,
      "allocation seam automatically disarms");
   Copy.Release;

   declare
      Data : Terminal.App.Graphics.Graphics_Data_Preview;
      Encoded_Length : Natural;
      Propagated : Boolean := False;
   begin
      begin
         Terminal.App.Graphics.Decoder_Testing.Decode_Base64_Zlib_PNG_Chunk_Rows
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
end Terminal.App.Image_Pipeline_Units_Smoke;
