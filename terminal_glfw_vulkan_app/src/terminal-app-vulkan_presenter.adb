with System;

with Terminal.Common.Bytes;
with Terminal.Common.Status;
with Terminal.App.Status_Labels;

package body Terminal.App.Vulkan_Presenter is
   use type System.Address;

   package VC renames Terminal.App.Vulkan_Context;
   package VD renames Terminal.App.Vulkan_Device;
   package VS renames Terminal.App.Vulkan_Submit;
   package RM renames Terminal.App.Render_Model;

   use type VS.Vertex_Array_Access;
   use type VS.Texture_Source;
   use type VD.Create_Status;
   use type VD.Render_Status;

   function Trimmed_Natural (Value : Natural) return String is
      Text : constant String := Natural'Image (Value);
   begin
      return Text (Text'First + 1 .. Text'Last);
   end Trimmed_Natural;

   function Humanize (Text : String) return String
      renames Terminal.App.Status_Labels.Humanize;

   function To_Present_Status
     (Status : VD.Render_Status)
      return Present_Status is
   begin
      case Status is
         when VD.Ok =>
            return Ok;
         when VD.Device_Lost =>
            return Device_Lost;
         when VD.Acquire_Image_Failed =>
            return Acquire_Image_Failed;
         when VD.Swapchain_Out_Of_Date =>
            return Swapchain_Out_Of_Date;
         when VD.Wait_Fence_Failed =>
            return Wait_Fence_Failed;
         when VD.Reset_Fence_Failed =>
            return Reset_Fence_Failed;
         when VD.Reset_Command_Buffer_Failed =>
            return Reset_Command_Buffer_Failed;
         when VD.Begin_Command_Buffer_Failed =>
            return Begin_Command_Buffer_Failed;
         when VD.End_Command_Buffer_Failed =>
            return End_Command_Buffer_Failed;
         when VD.Queue_Submit_Failed =>
            return Queue_Submit_Failed;
         when VD.Queue_Present_Failed =>
            return Queue_Present_Failed;
         when VD.Not_Initialized =>
            return Not_Initialized;
         when VD.No_Uploaded_Vertices =>
            return Render_Failed;
      end case;
   end To_Present_Status;

   function Status_Label (Status : Present_Status) return String is
      Image : constant String := Present_Status'Image (Status);
      Text  : constant String := Humanize (Image);
      Label : constant String := "Present: " & Text;
   begin
      if Label'Length > Max_Status_Label_Length then
         return Label (1 .. Max_Status_Label_Length);
      else
         return Label;
      end if;
   end Status_Label;

   function Has_Surface (Context : VC.Context) return Boolean is
     (VC.Surface (Context) /= System.Null_Address);

   function Batch_Is_Valid (Batch : VS.Submission_Batch) return Boolean is
   begin
      if VS.Width (Batch) = 0
        or else VS.Height (Batch) = 0
        or else VS.Vertex_Count (Batch) = 0
        or else VS.Vertices (Batch) = null
      then
         return False;
      end if;

      if VS.Text_Atlas_Used (Batch) then
         return VS.Atlas_Width (Batch) > 0
           and then VS.Atlas_Height (Batch) > 0
           and then VS.Atlas_Bytes (Batch) > 0
           and then VS.Atlas_Pixels (Batch) /= System.Null_Address;
      end if;

      return True;
   end Batch_Is_Valid;

   procedure Remember_Rejection
     (P      : in out Presenter;
      Status : Present_Status) is
   begin
      P.Rejected_Frames := P.Rejected_Frames + 1;
      P.Last_Status := Status;
      P.Last_Vertex_Count := 0;
      P.Last_Image_Command_Count := 0;
      P.Last_Image_Vertex_Count := 0;
      P.Last_Image_Texture_Vertex_Count := 0;
      P.Last_Image_Protocol := RM.Image_Sixel;
      P.Last_Image_Width := 0;
      P.Last_Image_Height := 0;
      P.Last_Image_Raw_Format := 0;
      P.Last_Image_Pixel_Width := 0;
      P.Last_Image_Pixel_Height := 0;
      P.Last_Image_Payload_Length := 0;
      P.Last_Image_Payload_Preview_Complete := False;
      P.Last_Image_Encoded_Preview_Length := 0;
      P.Last_Image_Decoded_Preview_Length := 0;
      P.Last_Image_Decoded_Preview_Bytes := (others => 0);
      P.Last_Image_Preview_Decode_Complete := False;
      P.Last_Image_Decode_Status := RM.Image_Decode_Not_Attempted;
      P.Last_Image_Placeholder := False;
      P.Last_Image_Texture_Downgraded := False;
      P.Last_Image_Texture_Source := VS.Texture_None;
      P.Last_Text_Run_Count := 0;
      P.Last_Shaped_Glyph_Count := 0;
      P.Last_Frame_Width := 0;
      P.Last_Frame_Height := 0;
      P.Last_Atlas_Bytes := 0;
      P.Atlas_Dirty := False;
      P.Has_Uploaded_Frame := False;
   end Remember_Rejection;

   procedure Initialize
     (P       : out Presenter;
      Context : VC.Context;
      Status  : out Init_Status;
      Desired_Width : Natural := 0;
      Desired_Height : Natural := 0) is
   begin
      P.Initialized := False;
      P.Context_Ready := False;
      P.Surface_Ready := False;
      P.Accepted_Frames := 0;
      P.Rejected_Frames := 0;
      P.Last_Status := Not_Initialized;
      P.Last_Vertex_Count := 0;
      P.Last_Image_Command_Count := 0;
      P.Last_Image_Vertex_Count := 0;
      P.Last_Image_Texture_Vertex_Count := 0;
      P.Last_Image_Protocol := RM.Image_Sixel;
      P.Last_Image_Width := 0;
      P.Last_Image_Height := 0;
      P.Last_Image_Raw_Format := 0;
      P.Last_Image_Pixel_Width := 0;
      P.Last_Image_Pixel_Height := 0;
      P.Last_Image_Payload_Length := 0;
      P.Last_Image_Payload_Preview_Complete := False;
      P.Last_Image_Encoded_Preview_Length := 0;
      P.Last_Image_Decoded_Preview_Length := 0;
      P.Last_Image_Decoded_Preview_Bytes := (others => 0);
      P.Last_Image_Preview_Decode_Complete := False;
      P.Last_Image_Decode_Status := RM.Image_Decode_Not_Attempted;
      P.Last_Image_Placeholder := False;
      P.Last_Image_Texture_Downgraded := False;
      P.Last_Image_Texture_Source := VS.Texture_None;
      P.Last_Text_Run_Count := 0;
      P.Last_Shaped_Glyph_Count := 0;
      P.Last_Frame_Width := 0;
      P.Last_Frame_Height := 0;
      P.Last_Atlas_Bytes := 0;
      P.Atlas_Dirty := False;
      P.Has_Uploaded_Frame := False;

      if not VC.Is_Initialized (Context) then
         Status := Context_Not_Initialized;
         return;
      end if;

      if not Has_Surface (Context) then
         Status := Surface_Unavailable;
         return;
      end if;

      declare
         Device_Status : VD.Select_Status;
         Create_Status : VD.Create_Status;
      begin
         VD.Select_Physical_Device (Context, P.Device, Device_Status);
         case Device_Status is
            when VD.Ok =>
               null;
            when VD.Surface_Query_Failed =>
               Status := Surface_Query_Failed;
               return;
            when VD.Context_Not_Initialized =>
               Status := Context_Not_Initialized;
               return;
            when VD.No_Physical_Devices | VD.No_Suitable_Device =>
               Status := No_Suitable_Device;
               return;
         end case;

         VD.Create_Logical_Device
           (Choice         => P.Device,
            Surface        => VC.Surface (Context),
            Desired_Width  => Desired_Width,
            Desired_Height => Desired_Height,
            Device         => P.Logical_Device,
            Status         => Create_Status);
         case Create_Status is
            when VD.Ok =>
               null;
            when VD.Device_Lost =>
               Status := Device_Lost;
               return;
            when VD.Swapchain_Extension_Missing =>
               Status := Swapchain_Extension_Missing;
               return;
            when VD.Queue_Unavailable =>
               Status := Queue_Unavailable;
               return;
            when VD.Invalid_Extent =>
               Status := Invalid_Extent;
               return;
            when VD.Create_Swapchain_Failed =>
               Status := Create_Swapchain_Failed;
               return;
            when VD.Get_Swapchain_Images_Failed =>
               Status := Get_Swapchain_Images_Failed;
               return;
            when VD.Too_Many_Swapchain_Images =>
               Status := Too_Many_Swapchain_Images;
               return;
            when VD.Create_Image_View_Failed =>
               Status := Create_Image_View_Failed;
               return;
            when VD.Create_Render_Pass_Failed =>
               Status := Create_Render_Pass_Failed;
               return;
            when VD.Create_Framebuffer_Failed =>
               Status := Create_Framebuffer_Failed;
               return;
            when VD.Create_Command_Pool_Failed =>
               Status := Create_Command_Pool_Failed;
               return;
            when VD.Allocate_Command_Buffers_Failed =>
               Status := Allocate_Command_Buffers_Failed;
               return;
            when VD.Create_Sync_Failed =>
               Status := Create_Sync_Failed;
               return;
            when VD.Create_Pipeline_Layout_Failed =>
               Status := Create_Pipeline_Layout_Failed;
               return;
            when VD.Create_Descriptor_Set_Layout_Failed =>
               Status := Create_Descriptor_Set_Layout_Failed;
               return;
            when VD.Create_Descriptor_Pool_Failed =>
               Status := Create_Descriptor_Pool_Failed;
               return;
            when VD.Allocate_Descriptor_Set_Failed =>
               Status := Allocate_Descriptor_Set_Failed;
               return;
            when VD.Create_Atlas_Sampler_Failed =>
               Status := Create_Atlas_Sampler_Failed;
               return;
            when VD.Shader_Load_Failed =>
               Status := Shader_Load_Failed;
               return;
            when VD.Create_Shader_Module_Failed =>
               Status := Create_Shader_Module_Failed;
               return;
            when VD.Create_Graphics_Pipeline_Failed =>
               Status := Create_Graphics_Pipeline_Failed;
               return;
            when VD.Vertex_Buffer_Too_Large =>
               Status := Vertex_Buffer_Too_Large;
               return;
            when VD.Create_Vertex_Buffer_Failed =>
               Status := Create_Vertex_Buffer_Failed;
               return;
            when VD.Allocate_Vertex_Memory_Failed =>
               Status := Allocate_Vertex_Memory_Failed;
               return;
            when VD.Bind_Vertex_Buffer_Failed =>
               Status := Bind_Vertex_Buffer_Failed;
               return;
            when VD.Map_Vertex_Buffer_Failed =>
               Status := Map_Vertex_Buffer_Failed;
               return;
            when VD.Atlas_Too_Large =>
               Status := Atlas_Too_Large;
               return;
            when VD.Image_Staging_Invalid_Source =>
               Status := Image_Staging_Invalid_Source;
               return;
            when VD.Image_Staging_Allocation_Failed =>
               Status := Image_Staging_Allocation_Failed;
               return;
            when VD.Create_Atlas_Image_Failed =>
               Status := Create_Atlas_Image_Failed;
               return;
            when VD.Allocate_Atlas_Memory_Failed =>
               Status := Allocate_Atlas_Memory_Failed;
               return;
            when VD.Bind_Atlas_Image_Failed =>
               Status := Bind_Atlas_Image_Failed;
               return;
            when VD.Create_Atlas_View_Failed =>
               Status := Create_Atlas_View_Failed;
               return;
            when VD.Create_Atlas_Staging_Buffer_Failed =>
               Status := Create_Atlas_Staging_Buffer_Failed;
               return;
            when VD.Allocate_Atlas_Staging_Memory_Failed =>
               Status := Allocate_Atlas_Staging_Memory_Failed;
               return;
            when VD.Bind_Atlas_Staging_Buffer_Failed =>
               Status := Bind_Atlas_Staging_Buffer_Failed;
               return;
            when VD.Map_Atlas_Staging_Buffer_Failed =>
               Status := Map_Atlas_Staging_Buffer_Failed;
               return;
            when VD.Copy_Atlas_Failed =>
               Status := Copy_Atlas_Failed;
               return;
            when VD.Selection_Not_Ready =>
               Status := Selection_Not_Ready;
               return;
            when VD.Resources_In_Flight =>
               Status := Resources_In_Flight;
               return;
            when VD.Create_Device_Failed =>
               Status := Create_Device_Failed;
               return;
            when VD.Create_Color_Target_Failed =>
               Status := Create_Color_Target_Failed;
               return;
            when VD.Surface_Query_Failed =>
               Status := Surface_Query_Failed;
               return;
         end case;
      end;

      P.Initialized := True;
      P.Context_Ready := True;
      P.Surface_Ready := True;
      P.Last_Status := Validated_Not_Presented;
      Status := Ok;
   end Initialize;

   procedure Present
     (P       : in out Presenter;
      Context : VC.Context;
      Batch   : VS.Submission_Batch;
      Status  : out Present_Status)
   is
      Previous_Preview_Length : constant Natural := Natural'Min
        (P.Last_Image_Decoded_Preview_Length,
         RM.Max_Image_Decoded_Preview_Length);
   begin
      if not P.Initialized then
         Status := Not_Initialized;
         Remember_Rejection (P, Status);
         return;
      end if;

      if not VC.Is_Initialized (Context) or else not Has_Surface (Context) then
         P.Context_Ready := VC.Is_Initialized (Context);
         P.Surface_Ready := Has_Surface (Context);
         Status := Invalid_Context;
         Remember_Rejection (P, Status);
         return;
      end if;

      if not VD.Is_Initialized (P.Logical_Device) then
         Status := Invalid_Context;
         Remember_Rejection (P, Status);
         return;
      end if;

      P.Context_Ready := True;
      P.Surface_Ready := True;

      if not Batch_Is_Valid (Batch) then
         Status := Invalid_Batch;
         Remember_Rejection (P, Status);
         return;
      end if;

      declare
         Upload_Status : VD.Create_Status;
         Render_Status : VD.Render_Status;
      begin
         --  A failed upload may have replaced or invalidated a previous GPU
         --  buffer, so retained presentation is permitted only after this
         --  upload has completed successfully.
         P.Has_Uploaded_Frame := False;
         VD.Upload (P.Logical_Device, P.Device, Batch, Upload_Status);
         if Upload_Status /= VD.Ok then
            if Upload_Status = VD.Device_Lost then
               Status := Device_Lost;
               Remember_Rejection (P, Status);
               return;
            elsif Upload_Status = VD.Resources_In_Flight then
               Status := Resources_In_Flight;
               Remember_Rejection (P, Status);
               return;
            end if;
            case Upload_Status is
               when VD.Image_Staging_Invalid_Source =>
                  Status := Image_Staging_Invalid_Source;
               when VD.Image_Staging_Allocation_Failed =>
                  Status := Image_Staging_Allocation_Failed;
               when VD.Atlas_Too_Large
                  | VD.Create_Atlas_Image_Failed
                  | VD.Allocate_Atlas_Memory_Failed
                  | VD.Bind_Atlas_Image_Failed
                  | VD.Create_Atlas_View_Failed
                  | VD.Create_Atlas_Staging_Buffer_Failed
                  | VD.Allocate_Atlas_Staging_Memory_Failed
                  | VD.Bind_Atlas_Staging_Buffer_Failed
                  | VD.Map_Atlas_Staging_Buffer_Failed
                  | VD.Copy_Atlas_Failed =>
                  Status := Atlas_Upload_Failed;
               when VD.Ok
                  | VD.Selection_Not_Ready
                  | VD.Device_Lost
                  | VD.Resources_In_Flight
                  | VD.Swapchain_Extension_Missing
                  | VD.Create_Device_Failed
                  | VD.Queue_Unavailable
                  | VD.Surface_Query_Failed
                  | VD.Invalid_Extent
                  | VD.Create_Swapchain_Failed
                  | VD.Get_Swapchain_Images_Failed
                  | VD.Too_Many_Swapchain_Images
                  | VD.Create_Image_View_Failed
                  | VD.Create_Color_Target_Failed
                  | VD.Create_Render_Pass_Failed
                  | VD.Create_Framebuffer_Failed
                  | VD.Create_Command_Pool_Failed
                  | VD.Allocate_Command_Buffers_Failed
                  | VD.Create_Sync_Failed
                  | VD.Create_Pipeline_Layout_Failed
                  | VD.Create_Descriptor_Set_Layout_Failed
                  | VD.Create_Descriptor_Pool_Failed
                  | VD.Allocate_Descriptor_Set_Failed
                  | VD.Create_Atlas_Sampler_Failed
                  | VD.Shader_Load_Failed
                  | VD.Create_Shader_Module_Failed
                  | VD.Create_Graphics_Pipeline_Failed
                  | VD.Vertex_Buffer_Too_Large
                  | VD.Create_Vertex_Buffer_Failed
                  | VD.Allocate_Vertex_Memory_Failed
                  | VD.Bind_Vertex_Buffer_Failed
                  | VD.Map_Vertex_Buffer_Failed =>
                  Status := Upload_Failed;
            end case;
            Remember_Rejection (P, Status);
            return;
         end if;
         P.Has_Uploaded_Frame := True;

         VD.Render (P.Logical_Device, Render_Status);
         if Render_Status /= VD.Ok then
            Status := To_Present_Status (Render_Status);
            Remember_Rejection (P, Status);
            return;
         end if;
      end;

      P.Accepted_Frames := P.Accepted_Frames + 1;
      P.Last_Vertex_Count := VS.Vertex_Count (Batch);
      P.Last_Image_Command_Count := VS.Image_Command_Count (Batch);
      P.Last_Image_Vertex_Count := VS.Image_Vertex_Count (Batch);
      P.Last_Image_Texture_Vertex_Count :=
        VS.Image_Texture_Vertex_Count (Batch);
      P.Last_Image_Protocol := VS.Last_Image_Protocol (Batch);
      P.Last_Image_Width := VS.Last_Image_Width (Batch);
      P.Last_Image_Height := VS.Last_Image_Height (Batch);
      P.Last_Image_Raw_Format := VS.Last_Image_Raw_Format (Batch);
      P.Last_Image_Pixel_Width := VS.Last_Image_Pixel_Width (Batch);
      P.Last_Image_Pixel_Height := VS.Last_Image_Pixel_Height (Batch);
      P.Last_Image_Payload_Length := VS.Last_Image_Payload_Length (Batch);
      P.Last_Image_Payload_Preview_Complete :=
        VS.Last_Image_Payload_Preview_Complete (Batch);
      P.Last_Image_Encoded_Preview_Length :=
        VS.Last_Image_Encoded_Preview_Length (Batch);
      P.Last_Image_Decoded_Preview_Length :=
        VS.Last_Image_Decoded_Preview_Length (Batch);
      for I in P.Last_Image_Decoded_Preview_Length + 1 ..
        Previous_Preview_Length
      loop
         P.Last_Image_Decoded_Preview_Bytes (I) := 0;
      end loop;
      for I in 1 .. Natural'Min
        (P.Last_Image_Decoded_Preview_Length,
         RM.Max_Image_Decoded_Preview_Length)
      loop
         P.Last_Image_Decoded_Preview_Bytes (I) :=
           VS.Last_Image_Decoded_Preview_Byte (Batch, I);
      end loop;
      P.Last_Image_Preview_Decode_Complete :=
        VS.Last_Image_Preview_Decode_Complete (Batch);
      P.Last_Image_Decode_Status := VS.Last_Image_Decode_Status (Batch);
      P.Last_Image_Placeholder := VS.Last_Image_Placeholder (Batch);
      P.Last_Image_Texture_Downgraded :=
        VS.Last_Image_Texture_Downgraded (Batch);
      P.Last_Image_Texture_Source := VS.Last_Image_Texture_Source (Batch);
      P.Last_Text_Run_Count := VS.Text_Run_Count (Batch);
      P.Last_Shaped_Glyph_Count := VS.Shaped_Glyph_Count (Batch);
      P.Last_Frame_Width := VS.Width (Batch);
      P.Last_Frame_Height := VS.Height (Batch);
      P.Last_Atlas_Bytes := VS.Atlas_Bytes (Batch);
      P.Atlas_Dirty := VS.Atlas_Dirty (Batch);
      P.Last_Status := Ok;
      Status := Ok;
   end Present;

   procedure Present_Retained
     (P       : in out Presenter;
      Context : VC.Context;
      Status  : out Present_Status)
   is
      Render_Status : VD.Render_Status;
   begin
      if not P.Initialized then
         Status := Not_Initialized;
         Remember_Rejection (P, Status);
         return;
      end if;

      if not VC.Is_Initialized (Context) or else not Has_Surface (Context) then
         P.Context_Ready := VC.Is_Initialized (Context);
         P.Surface_Ready := Has_Surface (Context);
         Status := Invalid_Context;
         Remember_Rejection (P, Status);
         return;
      end if;

      if not VD.Is_Initialized (P.Logical_Device) then
         Status := Invalid_Context;
         Remember_Rejection (P, Status);
         return;
      end if;

      P.Context_Ready := True;
      P.Surface_Ready := True;

      if not P.Has_Uploaded_Frame then
         Status := Invalid_Batch;
         Remember_Rejection (P, Status);
         return;
      end if;

      VD.Render (P.Logical_Device, Render_Status);
      if Render_Status /= VD.Ok then
         Status := To_Present_Status (Render_Status);
         Remember_Rejection (P, Status);
         return;
      end if;

      P.Accepted_Frames := P.Accepted_Frames + 1;
      P.Last_Status := Ok;
      Status := Ok;
   end Present_Retained;

   procedure Enable_Framebuffer_Readback
     (P      : in out Presenter;
      Status : out Readback_Status) is
   begin
      VD.Enable_Framebuffer_Readback (P.Logical_Device, P.Device, Status);
   end Enable_Framebuffer_Readback;

   procedure Readback_Pixel
     (P      : in out Presenter;
      X, Y   : Natural;
      Red, Green, Blue, Alpha : out Terminal.Common.Bytes.Byte;
      Status : out Readback_Status) is
   begin
      VD.Readback_Pixel
        (P.Logical_Device, X, Y, Red, Green, Blue, Alpha, Status);
   end Readback_Pixel;

   overriding procedure Finalize (P : in out Presenter) is
   begin
      VD.Finalize (P.Logical_Device);
      P.Initialized := False;
      P.Context_Ready := False;
      P.Surface_Ready := False;
      P.Has_Uploaded_Frame := False;
      P.Last_Status := Not_Initialized;
   exception
      when others =>
         P.Initialized := False;
         P.Has_Uploaded_Frame := False;
         P.Last_Status := Not_Initialized;
   end Finalize;

   function Is_Initialized (P : Presenter) return Boolean is
     (P.Initialized);

   function Diagnostics (P : Presenter) return Diagnostic_Snapshot is
   begin
      return
        (Initialized       => P.Initialized,
         Context_Ready     => P.Context_Ready,
         Surface_Ready     => P.Surface_Ready,
         Accepted_Frames   => P.Accepted_Frames,
         Rejected_Frames   => P.Rejected_Frames,
         Last_Status       => P.Last_Status,
         Last_Vertex_Count => P.Last_Vertex_Count,
         Last_Image_Command_Count => P.Last_Image_Command_Count,
         Last_Image_Vertex_Count => P.Last_Image_Vertex_Count,
         Last_Image_Texture_Vertex_Count =>
           P.Last_Image_Texture_Vertex_Count,
         Last_Image_Protocol => P.Last_Image_Protocol,
         Last_Image_Width => P.Last_Image_Width,
         Last_Image_Height => P.Last_Image_Height,
         Last_Image_Raw_Format => P.Last_Image_Raw_Format,
         Last_Image_Pixel_Width => P.Last_Image_Pixel_Width,
         Last_Image_Pixel_Height => P.Last_Image_Pixel_Height,
         Last_Image_Payload_Length => P.Last_Image_Payload_Length,
         Last_Image_Payload_Preview_Complete =>
           P.Last_Image_Payload_Preview_Complete,
         Last_Image_Encoded_Preview_Length =>
           P.Last_Image_Encoded_Preview_Length,
         Last_Image_Decoded_Preview_Length =>
           P.Last_Image_Decoded_Preview_Length,
         Last_Image_Decoded_Preview_Bytes =>
           P.Last_Image_Decoded_Preview_Bytes,
         Last_Image_Preview_Decode_Complete =>
           P.Last_Image_Preview_Decode_Complete,
         Last_Image_Decode_Status => P.Last_Image_Decode_Status,
         Last_Image_Placeholder => P.Last_Image_Placeholder,
         Last_Image_Texture_Downgraded => P.Last_Image_Texture_Downgraded,
         Last_Image_Texture_Source => P.Last_Image_Texture_Source,
         Last_Text_Run_Count => P.Last_Text_Run_Count,
         Last_Shaped_Glyph_Count => P.Last_Shaped_Glyph_Count,
         Last_Frame_Width  => P.Last_Frame_Width,
         Last_Frame_Height => P.Last_Frame_Height,
         Last_Atlas_Bytes  => P.Last_Atlas_Bytes,
         Atlas_Dirty       => P.Atlas_Dirty,
         Device            => VD.Diagnostics (P.Device),
         Logical_Device    => VD.Diagnostics (P.Logical_Device));
   end Diagnostics;

   function Image_Status_Label
     (Diagnostics : Diagnostic_Snapshot) return String
   is
      function Protocol_Name return String is
      begin
         case Diagnostics.Last_Image_Protocol is
            when RM.Image_Sixel =>
               return "sixel";
            when RM.Image_Kitty =>
               return "kitty";
            when RM.Image_ITerm2 =>
               return "iTerm2";
         end case;
      end Protocol_Name;

   begin
      if Diagnostics.Last_Image_Command_Count = 0 then
         return "";
      end if;

      return
        "presented image " & Protocol_Name
        & " size=" & Trimmed_Natural (Diagnostics.Last_Image_Width)
        & "x" & Trimmed_Natural (Diagnostics.Last_Image_Height)
        & (if Diagnostics.Last_Image_Pixel_Width > 0
           and then Diagnostics.Last_Image_Pixel_Height > 0
           then
             " pixels=" & Trimmed_Natural (Diagnostics.Last_Image_Pixel_Width)
             & "x" & Trimmed_Natural (Diagnostics.Last_Image_Pixel_Height)
             & " format=" & Trimmed_Natural (Diagnostics.Last_Image_Raw_Format)
           else "")
        & " vertices=" & Trimmed_Natural (Diagnostics.Last_Image_Vertex_Count)
        & " payload=" & Trimmed_Natural (Diagnostics.Last_Image_Payload_Length)
        & RM.Image_Payload_Status_Suffix
            (Diagnostics.Last_Image_Payload_Preview_Complete)
        & " preview="
        & Trimmed_Natural (Diagnostics.Last_Image_Decoded_Preview_Length)
        & "/"
        & Trimmed_Natural (Diagnostics.Last_Image_Encoded_Preview_Length)
        & Terminal.Common.Status.Preview_Bytes_Label
            (Diagnostics.Last_Image_Decoded_Preview_Bytes,
             Diagnostics.Last_Image_Decoded_Preview_Length)
        & " texture="
        & VS.Texture_Source_Label (Diagnostics.Last_Image_Texture_Source)
        & (if Diagnostics.Last_Image_Placeholder
           then " placeholder"
           else " textured")
        & (if Diagnostics.Last_Image_Texture_Downgraded
           then " downgraded"
           else "")
        & (if Diagnostics.Last_Image_Preview_Decode_Complete
           then " decoded"
           else " partial")
        & RM.Image_Decode_Status_Suffix
            (Diagnostics.Last_Image_Decode_Status);
   end Image_Status_Label;

   function Image_Texture_Status_Label
     (Diagnostics : Diagnostic_Snapshot) return String
   is
   begin
      if Diagnostics.Last_Image_Command_Count = 0 then
         return "";
      elsif Diagnostics.Last_Image_Texture_Downgraded then
         return
           "presenter image texture downgraded; texture="
           & VS.Texture_Source_Label (Diagnostics.Last_Image_Texture_Source)
           & " vertices="
           & Trimmed_Natural (Diagnostics.Last_Image_Texture_Vertex_Count);
      elsif Diagnostics.Last_Image_Texture_Source = VS.Texture_Image
        and then not Diagnostics.Last_Image_Placeholder
      then
         return
           "presenter image texture ready; vertices="
           & Trimmed_Natural (Diagnostics.Last_Image_Texture_Vertex_Count);
      else
         return
           "presenter image texture unavailable; texture="
           & VS.Texture_Source_Label (Diagnostics.Last_Image_Texture_Source)
           & " vertices="
           & Trimmed_Natural (Diagnostics.Last_Image_Texture_Vertex_Count);
      end if;
   end Image_Texture_Status_Label;

   function Image_Texture_Resource_Status_Label
     (Diagnostics : Diagnostic_Snapshot) return String
   is
   begin
      return VD.Image_Texture_Resource_Status_Label (Diagnostics.Logical_Device);
   end Image_Texture_Resource_Status_Label;
end Terminal.App.Vulkan_Presenter;
