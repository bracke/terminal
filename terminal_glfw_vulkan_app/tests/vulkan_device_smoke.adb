with AUnit.Assertions;
with System;

with Terminal.Common.Bytes;
with Terminal.App.Render_Model;
with Terminal.App.Vulkan_Context;
with Terminal.App.Vulkan_Device;
with Terminal.App.Vulkan_Submit;

procedure Vulkan_Device_Smoke is
   use AUnit.Assertions;
   use type Terminal.Common.Bytes.Byte;
   use type Terminal.App.Render_Model.Image_Decode_Status;
   use type Terminal.App.Render_Model.Image_Protocol;
   use type Terminal.App.Vulkan_Device.Create_Status;
   use type Terminal.App.Vulkan_Device.Render_Status;
   use type Terminal.App.Vulkan_Device.Select_Status;
   use type Terminal.App.Vulkan_Submit.Texture_Source;

   package VC renames Terminal.App.Vulkan_Context;
   package VD renames Terminal.App.Vulkan_Device;
   package VS renames Terminal.App.Vulkan_Submit;

   Context : VC.Context;
   Choice : VD.Selection;
   Device : VD.Logical_Device;
   Select_Status : VD.Select_Status;
   Create_Status : VD.Create_Status;
   Render_Status : VD.Render_Status;
begin
   Assert
     (VD.Select_Status_Label (VD.Ok) = "Select device: Ok",
      "select ok status label");
   Assert
     (VD.Select_Status_Label (VD.No_Suitable_Device) =
      "Select device: No Suitable Device",
      "select failure status label");
   Assert
     (VD.Create_Status_Label (VD.Create_Swapchain_Failed) =
      "Create device: Create Swapchain Failed",
      "create failure status label");
   Assert
     (VD.Render_Status_Label (VD.Queue_Present_Failed) =
      "Render device: Queue Present Failed",
      "render failure status label");
   Assert
     (VD.Create_Status_Label (VD.Create_Swapchain_Failed)'Length <=
      VD.Max_Status_Label_Length,
      "device status label should be bounded");
   Assert
     (VD.Image_Texture_Status_Label
        ((Uploaded_Image_Command_Count => 1,
          Uploaded_Image_Texture_Vertex_Count => 6,
          Uploaded_Image_Placeholder => False,
          Uploaded_Image_Texture_Source => VS.Texture_Image,
          others => <>)) =
      "device image texture ready; vertices=6",
      "ready device image texture status label");
   Assert
     (VD.Image_Texture_Status_Label
        ((Uploaded_Image_Command_Count => 1,
          Uploaded_Image_Texture_Vertex_Count => 6,
          Uploaded_Image_Placeholder => False,
          Uploaded_Image_Texture_Source => VS.Texture_Image,
          others => <>))'Length <= VD.Max_Status_Label_Length,
      "ready device image texture status label should be bounded");
   declare
      Diag : constant VD.Device_Diagnostic_Snapshot :=
        (Uploaded_Image_Command_Count => 1,
         Uploaded_Image_Texture_Vertex_Count => 6,
         Uploaded_Image_Texture_Staging_Bytes => 4,
         Uploaded_Image_Texture_Source => VS.Texture_Image,
         others => <>);
   begin
      Assert
        (Diag.Uploaded_Image_Texture_Staging_Bytes = 4,
         "device diagnostics should carry image texture staging byte count");
   end;
   Assert
     (VD.Image_Texture_Resource_Status_Label
        ((Uploaded_Image_Command_Count => 1,
          Uploaded_Image_Texture_Vertex_Count => 6,
          Image_Texture_Descriptor_Capacity => 4,
          Image_Texture_Descriptor_Bound_Count => 2,
          Uploaded_Image_Placeholder => False,
          Uploaded_Image_Texture_Source => VS.Texture_Image,
          others => <>)) =
      "device image texture resources ready; vertices=6 descriptors=2/4",
      "pending device image texture resource status label");
   Assert
     (VD.Image_Texture_Resource_Status_Label
        ((Uploaded_Image_Command_Count => 1,
          Uploaded_Image_Texture_Vertex_Count => 6,
          Image_Texture_Descriptor_Capacity => 4,
          Image_Texture_Descriptor_Bound_Count => 2,
          Uploaded_Image_Placeholder => False,
          Uploaded_Image_Texture_Source => VS.Texture_Image,
          others => <>))'Length <= VD.Max_Status_Label_Length,
      "pending device image texture resource status label should be bounded");
   Assert
     (VD.Image_Status_Label
        ((Uploaded_Image_Command_Count => 1,
          Uploaded_Image_Vertex_Count => 6,
          Uploaded_Image_Protocol => Terminal.App.Render_Model.Image_Kitty,
          Uploaded_Image_Width => 30,
          Uploaded_Image_Height => 16,
          Uploaded_Image_Payload_Length => 15,
          Uploaded_Image_Payload_Preview_Complete => True,
          Uploaded_Image_Encoded_Preview_Length => 4,
          Uploaded_Image_Decoded_Preview_Length => 3,
          Uploaded_Image_Decoded_Preview_Bytes =>
            (1 => 16#41#, 2 => 16#42#, 3 => 16#43#, others => 0),
          Uploaded_Image_Preview_Decode_Complete => True,
          Uploaded_Image_Decode_Status =>
            Terminal.App.Render_Model.Image_Decode_Ok,
          Uploaded_Image_Placeholder => True,
          Uploaded_Image_Texture_Source => VS.Texture_None,
          others => <>)) =
      "uploaded image kitty size=30x16 vertices=6 payload=15 payload-complete preview=3/4 bytes=414243 texture=none placeholder decoded",
      "device image payload completeness status label");

   VD.Select_Physical_Device (Context, Choice, Select_Status);
   Assert
     (Select_Status = VD.Context_Not_Initialized,
      "uninitialized context must reject physical-device selection");
   Assert
     (VD.Select_Status_Label (Select_Status) =
      "Select device: Context Not Initialized",
      "uninitialized select status label");
   Assert (not VD.Is_Selected (Choice), "choice should not be selected");

   VD.Create_Logical_Device
     (Choice         => Choice,
      Surface        => System.Null_Address,
      Desired_Width  => 0,
      Desired_Height => 0,
      Device         => Device,
      Status         => Create_Status);
   Assert
     (Create_Status = VD.Selection_Not_Ready,
      "unselected physical device must reject logical-device creation");
   Assert
     (VD.Create_Status_Label (Create_Status) =
      "Create device: Selection Not Ready",
      "selection-not-ready create status label");
   Assert (not VD.Is_Initialized (Device), "logical device should not be live");

   VD.Render (Device, Render_Status);
   Assert
     (Render_Status = VD.Not_Initialized,
      "uninitialized logical device must reject render");
   Assert
     (VD.Render_Status_Label (Render_Status) =
      "Render device: Not Initialized",
      "not-initialized render status label");

   declare
      Diag : constant VD.Device_Diagnostic_Snapshot := VD.Diagnostics (Device);
   begin
      Assert
        (Diag.Last_Status = VD.Selection_Not_Ready,
         "device diagnostic should retain failure status");
      Assert
        (Diag.Color_Sample_Count = 1,
         "uninitialized device should report 1x color sampling");
      Assert
        (Diag.Uploaded_Text_Run_Count = 0,
         "uninitialized device should report no uploaded text runs");
      Assert
        (Diag.Uploaded_Image_Command_Count = 0,
         "uninitialized device should report no uploaded images");
      Assert
        (Diag.Uploaded_Image_Vertex_Count = 0,
         "uninitialized device should clear uploaded image vertices");
      Assert
        (Diag.Uploaded_Image_Texture_Vertex_Count = 0,
         "uninitialized device should clear uploaded image texture vertices");
      Assert
        (Diag.Image_Texture_Descriptor_Capacity = 0
         and then Diag.Image_Texture_Descriptor_Bound_Count = 0,
         "uninitialized device should report no image texture descriptors");
      Assert
        (Diag.Uploaded_Image_Protocol = Terminal.App.Render_Model.Image_Sixel,
         "uninitialized device should reset image protocol");
      Assert
        (Diag.Uploaded_Image_Width = 0
         and then Diag.Uploaded_Image_Height = 0,
         "uninitialized device should clear image dimensions");
      Assert
        (Diag.Uploaded_Image_Payload_Length = 0,
         "uninitialized device should report no image payload");
      Assert
        (not Diag.Uploaded_Image_Payload_Preview_Complete,
         "uninitialized device should clear image payload completeness");
      Assert
        (Diag.Uploaded_Image_Encoded_Preview_Length = 0,
         "uninitialized device should report no encoded image preview");
      Assert
        (Diag.Uploaded_Image_Decoded_Preview_Length = 0,
         "uninitialized device should report no decoded image preview");
      Assert
        (Diag.Uploaded_Image_Decoded_Preview_Bytes (1) = 0,
         "uninitialized device should clear decoded image preview bytes");
      Assert
        (not Diag.Uploaded_Image_Preview_Decode_Complete,
         "uninitialized device should not report complete image preview decode");
      Assert
        (Diag.Uploaded_Image_Decode_Status =
         Terminal.App.Render_Model.Image_Decode_Not_Attempted,
         "uninitialized device should clear image decode status");
      Assert
        (not Diag.Uploaded_Image_Placeholder,
         "uninitialized device should clear image placeholder flag");
      Assert
        (not Diag.Uploaded_Image_Texture_Downgraded,
         "uninitialized device should clear image downgrade flag");
      Assert
        (Diag.Uploaded_Image_Texture_Source = VS.Texture_None,
         "uninitialized device should clear image texture source");
      Assert
        (VD.Image_Status_Label (Diag) = "",
         "uninitialized device should not report image status");
      Assert
        (VD.Image_Texture_Status_Label (Diag) = "",
         "uninitialized device should not report image texture status");
      Assert
        (VD.Image_Texture_Resource_Status_Label (Diag) = "",
         "uninitialized device should not report image texture resource status");
      Assert
        (Diag.Uploaded_Shaped_Glyph_Count = 0,
         "uninitialized device should report no uploaded shaped glyphs");
      Assert
        (not Diag.Color_MSAA_Created,
         "uninitialized device should not report an MSAA target");
   end;
end Vulkan_Device_Smoke;
