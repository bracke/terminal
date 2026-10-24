with Ada.Unchecked_Deallocation;
with AUnit.Assertions;
with Interfaces;

with Terminal.App.Image_Decode;
with Terminal.App.Graphics;
with Terminal.App.Image_Ingestion;
with Terminal.App.Image_Media;
with Terminal.App.Image_Rendering;
with Terminal.App.Render_Model;
with Terminal.App.Renderer;
with Terminal.App.Image_Store;
with Terminal.Common.Bytes;

procedure Image_Pipeline_Units_Smoke is
   use AUnit.Assertions;
   use type Terminal.App.Render_Model.Image_Data_Access;
   use type Interfaces.Unsigned_64;

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

   Terminal.App.Image_Store.Fail_Allocation_After (Control, 1);
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
      Transaction : Terminal.App.Image_Store.Install_Transaction;
      Order : Interfaces.Unsigned_64;
   begin
      Terminal.App.Image_Store.Record_Install (Transaction, 42);
      Terminal.App.Image_Store.Take_Rollback_Order (Transaction, Order);
      Assert (Order = 42, "install transaction exposes rollback order once");
      Terminal.App.Image_Store.Take_Rollback_Order (Transaction, Order);
      Assert (Order = 0, "install transaction rollback is idempotent");
      Terminal.App.Image_Store.Record_Install (Transaction, 43);
      Terminal.App.Image_Store.Commit (Transaction);
      Terminal.App.Image_Store.Take_Rollback_Order (Transaction, Order);
      Assert (Order = 0, "committed install has no rollback order");
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
