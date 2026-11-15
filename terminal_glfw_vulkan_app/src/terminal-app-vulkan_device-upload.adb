separate (Terminal.App.Vulkan_Device)
   procedure Upload
     (Device : in out Logical_Device;
      Choice : Selection;
      Batch  : VS.Submission_Batch;
      Status : out Create_Status)
   is
      Count : constant Natural := VS.Vertex_Count (Batch);
      Previous_Preview_Length : constant Natural := Natural'Min
        (Device.Uploaded_Image_Decoded_Preview_Length,
         RM.Max_Image_Decoded_Preview_Length);
      Bytes : Interfaces.Unsigned_64;
      Data  : aliased System.Address := System.Null_Address;
      Result : Vk.Result_T;
      Frame_Resources_Available : Boolean;

      Mapped : Boolean := False;

      procedure Unmap_Vertex_Memory (Success : out Boolean) is
         procedure Perform_Unmap is
         begin
            Vk.Unmap_Memory (Device.Device, Device.Vertex_Memory);
         end Perform_Unmap;

         procedure Handle_Failure
           (E : Ada.Exceptions.Exception_Occurrence) is
         begin
            Device.Cleanup_Quarantined := True;
            Terminal.App.Cleanup_Diagnostics.Note_Failure
              (Terminal.App.Cleanup_Diagnostics.Vulkan_Device,
               E,
               "unmap Vulkan vertex memory");
            Device.Vertex_Buffer := System.Null_Address;
            Device.Vertex_Memory := System.Null_Address;
            Device.Vertex_Buffer_Bytes := 0;
         end Handle_Failure;
      begin
         Data := System.Null_Address;
         Terminal.App.Vulkan_Unmap_Once.Run
           (Mapped, Perform_Unmap'Access, Handle_Failure'Access, Success);
      end Unmap_Vertex_Memory;

      procedure Upload_Colour_Pixels (Pixels : System.Address) is
      begin
         Upload_Image_Texture_Data
           (Device        => Device,
            Choice        => Choice,
            Width         => VS.Colour_Atlas_Width (Batch),
            Height        => VS.Colour_Atlas_Height (Batch),
            Bytes_Natural => VS.Colour_Atlas_Bytes (Batch),
            Pixels        => Pixels,
            Status        => Status,
            Slot          => Colour_Glyphs);
      end Upload_Colour_Pixels;
   begin
      if not Device.Initialized
        or else not Choice.Selected
        or else not VS.Has_Vertex_Data (Batch)
      then
         Device.Uploaded_Image_Command_Count := 0;
         Device.Uploaded_Image_Vertex_Count := 0;
         Device.Uploaded_Image_Texture_Vertex_Count := 0;
         Device.Uploaded_Image_Texture_Staging_Bytes := 0;
         Device.Uploaded_Image_Protocol := RM.Image_Sixel;
         Device.Uploaded_Image_Width := 0;
         Device.Uploaded_Image_Height := 0;
         Device.Uploaded_Image_Raw_Format := 0;
         Device.Uploaded_Image_Pixel_Width := 0;
         Device.Uploaded_Image_Pixel_Height := 0;
         Device.Uploaded_Image_Payload_Length := 0;
         Device.Uploaded_Image_Payload_Preview_Complete := False;
         Device.Uploaded_Image_Encoded_Preview_Length := 0;
         Device.Uploaded_Image_Decoded_Preview_Length := 0;
         Device.Uploaded_Image_Decoded_Preview_Bytes := (others => 0);
         Device.Uploaded_Image_Preview_Decode_Complete := False;
         Device.Uploaded_Image_Decode_Status := RM.Image_Decode_Not_Attempted;
         Device.Uploaded_Image_Placeholder := False;
         Device.Uploaded_Image_Texture_Downgraded := False;
         Device.Uploaded_Image_Texture_Source := VS.Texture_None;
         Status := Selection_Not_Ready;
         return;
      end if;

      if Count = 0 or else Count > Max_Upload_Vertices then
         Device.Uploaded_Image_Command_Count := 0;
         Device.Uploaded_Image_Vertex_Count := 0;
         Device.Uploaded_Image_Texture_Vertex_Count := 0;
         Device.Uploaded_Image_Texture_Staging_Bytes := 0;
         Device.Uploaded_Image_Protocol := RM.Image_Sixel;
         Device.Uploaded_Image_Width := 0;
         Device.Uploaded_Image_Height := 0;
         Device.Uploaded_Image_Raw_Format := 0;
         Device.Uploaded_Image_Pixel_Width := 0;
         Device.Uploaded_Image_Pixel_Height := 0;
         Device.Uploaded_Image_Payload_Length := 0;
         Device.Uploaded_Image_Payload_Preview_Complete := False;
         Device.Uploaded_Image_Encoded_Preview_Length := 0;
         Device.Uploaded_Image_Decoded_Preview_Length := 0;
         Device.Uploaded_Image_Decoded_Preview_Bytes := (others => 0);
         Device.Uploaded_Image_Preview_Decode_Complete := False;
         Device.Uploaded_Image_Decode_Status := RM.Image_Decode_Not_Attempted;
         Device.Uploaded_Image_Placeholder := False;
         Device.Uploaded_Image_Texture_Downgraded := False;
         Device.Uploaded_Image_Texture_Source := VS.Texture_None;
         Status := Vertex_Buffer_Too_Large;
         return;
      end if;

      --  The descriptor set and vertex buffer are shared by submitted frames.
      --  Never update or retire either while a frame fence is unsignalled.
      --  Returning a retry status keeps the GUI responsive and avoids a
      --  queue-wide idle stall.
      Check_Frame_Resources
        (Device, Frame_Resources_Available, Status);
      if not Frame_Resources_Available then
         return;
      end if;

      if VS.Text_Atlas_Used (Batch) then
         Upload_Atlas (Device, Choice, Batch, Status);
         if Status /= Ok then
            return;
         end if;
      end if;

      --  Colour glyphs, when no image took the texture for this frame. They are
      --  already packed and already RGBA, so this is the plain upload rather than
      --  the row-converting one the image protocols need.
      --  Binding 2 has to point at something before anything draws: the shader
      --  can reach all three samplers whichever branch a pixel takes, and a
      --  descriptor nobody wrote is undefined. One transparent pixel does until
      --  there is a colour glyph to show.
      if VS.Colour_Atlas_Bytes (Batch) > 0
        and then
          (VS.Colour_Atlas_Dirty (Batch)
           or else Device.Colour_Sheet_View = System.Null_Address
           or else Device.Colour_Sheet_Width /= VS.Colour_Atlas_Width (Batch)
           or else Device.Colour_Sheet_Height /= VS.Colour_Atlas_Height (Batch))
      then
         if not VS.Has_Colour_Atlas_Pixels (Batch) then
            Status := Image_Staging_Invalid_Source;
            return;
         end if;
         VS.Visit_Colour_Atlas_Pixels
           (Batch, Upload_Colour_Pixels'Access);

         if Status /= Ok then
            return;
         end if;

      elsif Device.Colour_Sheet_View = System.Null_Address then
         declare
            Blank : aliased constant Blank_Pixel := [others => 0];
         begin
            Upload_Image_Texture_Data
              (Device        => Device,
               Choice        => Choice,
               Width         => 1,
               Height        => 1,
               Bytes_Natural => 4,
               Pixels        => Blank'Address,
               Status        => Status,
               Slot          => Colour_Glyphs);

            if Status /= Ok then
               return;
            end if;
         end;
      end if;

      if VS.Image_Atlas_Bytes (Batch) > 0 then
         Device.Uploaded_Image_Texture_Staging_Bytes :=
           VS.Image_Atlas_Bytes (Batch);
         Upload_Image_Atlas (Device, Choice, Batch, Status);
         if Status /= Ok then
            return;
         end if;
      elsif Device.Image_Texture_View = System.Null_Address
        or else Device.Image_Texture_Width /= 1
        or else Device.Image_Texture_Height /= 1
        or else Device.Image_Texture_Bytes /= 4
        or else Device.Image_Texture_Content_Signature /= 0
      then
         --  Binding 1 is statically used by the fragment shader even on a
         --  text-only frame. Keep it valid, and release a previous large image
         --  atlas by replacing it with one transparent pixel.
         declare
            Blank : aliased constant Blank_Pixel := [others => 0];
         begin
            Upload_Image_Texture_Data
              (Device        => Device,
               Choice        => Choice,
               Width         => 1,
               Height        => 1,
               Bytes_Natural => 4,
               Pixels        => Blank'Address,
               Status        => Status,
               Slot          => Inline_Picture);
            if Status /= Ok then
               return;
            end if;
         end;
      end if;

      Bytes := Interfaces.Unsigned_64 (Count) * Packed_Vertex_Bytes;
      Ensure_Vertex_Buffer (Device, Choice, Bytes, Status);
      if Status /= Ok then
         return;
      end if;

      Result :=
        Vk.Map_Memory
          (Device.Device,
           Device.Vertex_Memory,
           0,
           Bytes,
           0,
           Data'Address);
      Mapped := Result = Vk.SUCCESS;
      if Result /= Vk.SUCCESS or else Data = System.Null_Address then
         declare
            Cleanup_Ok : Boolean;
         begin
            Unmap_Vertex_Memory (Cleanup_Ok);
         end;
         Status := Map_Vertex_Buffer_Failed;
         return;
      end if;

      begin
         declare
            Target : constant Vertex_Mapping.Object_Pointer :=
           Vertex_Mapping.To_Pointer (Data);
         begin
            for I in 1 .. Count loop
               declare
                  Source : constant VS.Vertex := VS.Vertex_At (Batch, I);
               begin
                  Target.all (I) :=
                    (X          => Interfaces.C.C_float (Source.X),
                     Y          => Interfaces.C.C_float (Source.Y),
                     U          => Interfaces.C.C_float (Source.U),
                     V          => Interfaces.C.C_float (Source.V),
                     R          => Interfaces.C.C_float (Source.Color.R),
                     G          => Interfaces.C.C_float (Source.Color.G),
                     B          => Interfaces.C.C_float (Source.Color.B),
                     A          => Interfaces.C.C_float (Source.Color.A),
                     Textured   => To_Float (Source.Textured),
                     Texture_ID => Texture_ID (Source.Texture));
               end;
            end loop;
         end;
      exception
         when E : others =>
            Terminal.App.Cleanup_Diagnostics.Note_Failure
              (Terminal.App.Cleanup_Diagnostics.Vulkan_Device,
               E,
               "copy Vulkan vertex data");
            declare
               Cleanup_Ok : Boolean;
            begin
               Unmap_Vertex_Memory (Cleanup_Ok);
            end;
            Status := Map_Vertex_Buffer_Failed;
            return;
      end;

      declare
         Cleanup_Ok : Boolean;
      begin
         Unmap_Vertex_Memory (Cleanup_Ok);
         if not Cleanup_Ok then
            Status := Map_Vertex_Buffer_Failed;
            return;
         end if;
      end;
      Device.Uploaded_Vertex_Count := Count;
      Device.Uploaded_Image_Command_Count := VS.Image_Command_Count (Batch);
      Device.Uploaded_Image_Vertex_Count := VS.Image_Vertex_Count (Batch);
      Device.Uploaded_Image_Texture_Vertex_Count :=
        VS.Image_Texture_Vertex_Count (Batch);
      Device.Uploaded_Image_Protocol := VS.Last_Image_Protocol (Batch);
      Device.Uploaded_Image_Width := VS.Last_Image_Width (Batch);
      Device.Uploaded_Image_Height := VS.Last_Image_Height (Batch);
      Device.Uploaded_Image_Raw_Format := VS.Last_Image_Raw_Format (Batch);
      Device.Uploaded_Image_Pixel_Width := VS.Last_Image_Pixel_Width (Batch);
      Device.Uploaded_Image_Pixel_Height := VS.Last_Image_Pixel_Height (Batch);
      Device.Uploaded_Image_Payload_Length :=
        VS.Last_Image_Payload_Length (Batch);
      if VS.Image_Atlas_Bytes (Batch) = 0 then
         Device.Uploaded_Image_Texture_Staging_Bytes := 0;
      end if;
      Device.Uploaded_Image_Payload_Preview_Complete :=
        VS.Last_Image_Payload_Preview_Complete (Batch);
      Device.Uploaded_Image_Encoded_Preview_Length :=
        VS.Last_Image_Encoded_Preview_Length (Batch);
      Device.Uploaded_Image_Decoded_Preview_Length :=
        VS.Last_Image_Decoded_Preview_Length (Batch);
      for I in Device.Uploaded_Image_Decoded_Preview_Length + 1 ..
        Previous_Preview_Length
      loop
         Device.Uploaded_Image_Decoded_Preview_Bytes (I) := 0;
      end loop;
      for I in 1 .. Natural'Min
        (Device.Uploaded_Image_Decoded_Preview_Length,
         RM.Max_Image_Decoded_Preview_Length)
      loop
         Device.Uploaded_Image_Decoded_Preview_Bytes (I) :=
           VS.Last_Image_Decoded_Preview_Byte (Batch, I);
      end loop;
      Device.Uploaded_Image_Preview_Decode_Complete :=
        VS.Last_Image_Preview_Decode_Complete (Batch);
      Device.Uploaded_Image_Decode_Status :=
        VS.Last_Image_Decode_Status (Batch);
      Device.Uploaded_Image_Placeholder := VS.Last_Image_Placeholder (Batch);
      Device.Uploaded_Image_Texture_Downgraded :=
        VS.Last_Image_Texture_Downgraded (Batch);
      Device.Uploaded_Image_Texture_Source :=
        VS.Last_Image_Texture_Source (Batch);
      Device.Uploaded_Text_Run_Count := VS.Text_Run_Count (Batch);
      Device.Uploaded_Shaped_Glyph_Count := VS.Shaped_Glyph_Count (Batch);
      Status := Ok;
   end Upload;

