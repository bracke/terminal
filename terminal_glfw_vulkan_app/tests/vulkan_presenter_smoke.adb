with AUnit.Assertions;

with Terminal.Common.Bytes;
with Terminal.App.Render_Model;
with Terminal.App.Vulkan_Context;
with Terminal.App.Vulkan_Presenter;
with Terminal.App.Vulkan_Submit;

procedure Vulkan_Presenter_Smoke is
   use AUnit.Assertions;
   use type Terminal.Common.Bytes.Byte;
   use type Terminal.App.Render_Model.Image_Decode_Status;
   use type Terminal.App.Render_Model.Image_Protocol;
   use type Terminal.App.Vulkan_Presenter.Init_Status;
   use type Terminal.App.Vulkan_Presenter.Present_Status;
   use type Terminal.App.Vulkan_Submit.Texture_Source;

   package VC renames Terminal.App.Vulkan_Context;
   package VP renames Terminal.App.Vulkan_Presenter;
   package VS renames Terminal.App.Vulkan_Submit;

   Context : VC.Context;
   Presenter : VP.Presenter;
   Batch : VS.Submission_Batch;
   Init_Status : VP.Init_Status;
   Present_Status : VP.Present_Status;
begin
   Assert
     (VC.Status_Label (VC.Ok) = "Vulkan context: Ok",
      "context ok status label");
   Assert
     (VC.Status_Label (VC.Surface_Create_Failed) =
      "Vulkan context: Surface Create Failed",
      "context failure status label");
   Assert
     (VC.Status_Label (VC.Surface_Create_Failed)'Length <=
      VC.Max_Status_Label_Length,
      "context status label should be bounded");

   Assert
     (VP.Status_Label (VP.Ok) = "Present: Ok",
      "ok present status label");
   Assert
     (VP.Status_Label (VP.Queue_Present_Failed) =
      "Present: Queue Present Failed",
      "failed present status label");
   Assert
     (VP.Status_Label (VP.Queue_Present_Failed)'Length <=
      VP.Max_Status_Label_Length,
      "present status label should be bounded");
   Assert
     (VP.Image_Status_Label ((others => <>)) = "",
      "empty presenter image status label");
   Assert
     (VP.Image_Texture_Status_Label ((others => <>)) = "",
      "empty presenter image texture status label");
   Assert
     (VP.Image_Texture_Resource_Status_Label ((others => <>)) = "",
      "empty presenter image texture resource status label");
   Assert
     (VP.Image_Status_Label
        ((Last_Image_Command_Count => 1,
          Last_Image_Vertex_Count => 6,
          Last_Image_Protocol => Terminal.App.Render_Model.Image_Kitty,
          Last_Image_Width => 30,
          Last_Image_Height => 16,
          Last_Image_Payload_Length => 15,
          Last_Image_Payload_Preview_Complete => True,
          Last_Image_Encoded_Preview_Length => 4,
          Last_Image_Decoded_Preview_Length => 3,
          Last_Image_Decoded_Preview_Bytes =>
            (1 => 16#41#, 2 => 16#42#, 3 => 16#43#, others => 0),
          Last_Image_Preview_Decode_Complete => True,
          Last_Image_Decode_Status => Terminal.App.Render_Model.Image_Decode_Ok,
          Last_Image_Placeholder => True,
          Last_Image_Texture_Source => VS.Texture_None,
          others => <>)) =
      "presented image kitty size=30x16 vertices=6 payload=15 payload-complete preview=3/4 bytes=414243 texture=none placeholder decoded",
      "presenter image payload completeness status label");
   Assert
     (VP.Image_Texture_Status_Label
        ((Last_Image_Command_Count => 1,
          Last_Image_Texture_Vertex_Count => 6,
          Last_Image_Placeholder => False,
          Last_Image_Texture_Source => VS.Texture_Image,
          others => <>)) =
      "presenter image texture ready; vertices=6",
      "ready presenter image texture status label");
   Assert
     (VP.Image_Texture_Status_Label
        ((Last_Image_Command_Count => 1,
          Last_Image_Texture_Vertex_Count => 6,
          Last_Image_Placeholder => False,
          Last_Image_Texture_Source => VS.Texture_Image,
          others => <>))'Length <= VP.Max_Status_Label_Length,
      "ready presenter image texture status label should be bounded");
   Assert
     (VP.Image_Texture_Resource_Status_Label
        ((Logical_Device =>
             (Uploaded_Image_Command_Count => 1,
              Uploaded_Image_Texture_Vertex_Count => 6,
              Image_Texture_Descriptor_Capacity => 4,
              Image_Texture_Descriptor_Bound_Count => 2,
              Uploaded_Image_Placeholder => False,
              Uploaded_Image_Texture_Source => VS.Texture_Image,
              others => <>),
          others => <>)) =
      "device image texture resources ready; vertices=6 descriptors=2/4",
      "presenter image texture resource status label");
   Assert
     (VP.Image_Texture_Resource_Status_Label
        ((Logical_Device =>
             (Uploaded_Image_Command_Count => 1,
              Uploaded_Image_Texture_Vertex_Count => 6,
              Image_Texture_Descriptor_Capacity => 4,
              Image_Texture_Descriptor_Bound_Count => 2,
              Uploaded_Image_Placeholder => False,
              Uploaded_Image_Texture_Source => VS.Texture_Image,
              others => <>),
          others => <>))'Length <= VP.Max_Status_Label_Length,
      "presenter image texture resource status label should be bounded");

   VP.Initialize (Presenter, Context, Init_Status);
   Assert
     (Init_Status = VP.Context_Not_Initialized,
      "uninitialized Vulkan context must be rejected");

   VP.Present (Presenter, Context, Batch, Present_Status);
   Assert
     (Present_Status = VP.Not_Initialized,
      "present before initialize must be rejected");
   Assert
     (VP.Status_Label (Present_Status) = "Present: Not Initialized",
      "not initialized present status label");

   declare
      Diag : constant VP.Diagnostic_Snapshot := VP.Diagnostics (Presenter);
   begin
      Assert (not Diag.Initialized, "presenter should remain uninitialized");
      Assert (Diag.Rejected_Frames = 1, "rejected frame counter");
      Assert
        (Diag.Last_Status = VP.Not_Initialized,
         "last present status should be retained");
      Assert
        (Diag.Last_Image_Command_Count = 0,
         "rejected present should clear image command count");
      Assert
        (Diag.Last_Image_Vertex_Count = 0,
         "rejected present should clear image vertex count");
      Assert
        (Diag.Last_Image_Texture_Vertex_Count = 0,
         "rejected present should clear image texture vertex count");
      Assert
        (Diag.Last_Image_Protocol = Terminal.App.Render_Model.Image_Sixel,
         "rejected present should reset image protocol");
      Assert
        (Diag.Last_Image_Width = 0 and then Diag.Last_Image_Height = 0,
         "rejected present should clear image dimensions");
      Assert
        (Diag.Last_Image_Payload_Length = 0,
         "rejected present should clear image payload length");
      Assert
        (not Diag.Last_Image_Payload_Preview_Complete,
         "rejected present should clear image payload completeness");
      Assert
        (Diag.Last_Image_Encoded_Preview_Length = 0,
         "rejected present should clear encoded image preview length");
      Assert
        (Diag.Last_Image_Decoded_Preview_Length = 0,
         "rejected present should clear decoded image preview length");
      Assert
        (Diag.Last_Image_Decoded_Preview_Bytes (1) = 0,
         "rejected present should clear decoded image preview bytes");
      Assert
        (not Diag.Last_Image_Preview_Decode_Complete,
         "rejected present should clear image decode flag");
      Assert
        (Diag.Last_Image_Decode_Status =
         Terminal.App.Render_Model.Image_Decode_Not_Attempted,
         "rejected present should clear image decode status");
      Assert
        (not Diag.Last_Image_Placeholder,
         "rejected present should clear image placeholder flag");
      Assert
        (not Diag.Last_Image_Texture_Downgraded,
         "rejected present should clear image downgrade flag");
      Assert
        (Diag.Last_Image_Texture_Source = VS.Texture_None,
         "rejected present should clear image texture source");
      Assert
        (VP.Image_Status_Label (Diag) = "",
         "rejected present should not report image status");
      Assert
        (VP.Image_Texture_Status_Label (Diag) = "",
         "rejected present should not report image texture status");
      Assert
        (VP.Image_Texture_Resource_Status_Label (Diag) = "",
         "rejected present should not report image texture resource status");
      Assert
        (Diag.Last_Text_Run_Count = 0,
         "rejected present should clear text run count");
      Assert
        (Diag.Last_Shaped_Glyph_Count = 0,
         "rejected present should clear shaped glyph count");
   end;
end Vulkan_Presenter_Smoke;
