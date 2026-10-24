with Terminal.App.Image_Decode;
with Terminal.App.Image_Media;

package Terminal.App.Image_Rendering is
   Max_Status_Label_Length : constant := 64;

   type Media_Diagnostics is record
      Attempted : Boolean := False;
      Status : Terminal.App.Image_Decode.Status :=
        Terminal.App.Image_Decode.Decode_Not_Attempted;
      Error : Terminal.App.Image_Media.Decode_Diagnostic;
      Adapter_Buffer_Bytes : Natural := 0;
      Decoder_Configured_Bytes : Natural := 0;
      Warning_Count : Natural := 0;
      First_Warning : Terminal.App.Image_Media.Decode_Diagnostic;
   end record;

   procedure Clear (Diagnostics : out Media_Diagnostics);
   procedure Capture
     (Diagnostics : out Media_Diagnostics;
      Image       : Terminal.App.Image_Media.Decoded_Image;
      Status      : Terminal.App.Image_Decode.Status);
   procedure Set_Status
     (Diagnostics : out Media_Diagnostics;
      Status      : Terminal.App.Image_Decode.Status);

   function Animation_Capacity_Available
     (Retained : Natural;
      Incoming : Natural;
      Limit    : Natural) return Boolean;

   function Status_Label (Diagnostics : Media_Diagnostics) return String;
end Terminal.App.Image_Rendering;
