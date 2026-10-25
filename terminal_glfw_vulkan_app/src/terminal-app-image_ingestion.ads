with Terminal.App.Render_Model;
with Terminal.App.Image_Store;
with Terminal.App.Graphics;
with Terminal.App.Graphics_Transport;
with Terminal.Core;

package Terminal.App.Image_Ingestion is
   type Payload_Protocol is (Kitty, ITerm2);

   --  Return the first payload character, or zero when the command has no
   --  non-empty payload.  Protocol framing belongs to ingestion rather than
   --  the renderer.
   function Payload_Start
     (Protocol : Payload_Protocol;
      Text     : String) return Natural;

   function Copy_Text
     (Text    : String;
      Control : in out Terminal.App.Image_Store.Allocation_Control)
      return Terminal.App.Render_Model.Image_Data_Access;

   function Encode_Base64
     (Bytes  : Terminal.App.Graphics_Transport.Byte_Array_Access;
      Length : Natural) return String;

   type Pixel_Size is record
      Width  : Float := 0.0;
      Height : Float := 0.0;
   end record;

   --  Resolve iTerm2's cell, pixel, percentage and aspect-ratio controls into
   --  renderer-neutral pixel dimensions.
   function ITerm2_Render_Size
     (Header           : Terminal.App.Graphics.Graphics_Header;
      Intrinsic_Width  : Positive;
      Intrinsic_Height : Positive;
      Cell_Width       : Positive;
      Cell_Height      : Positive;
      View_Width       : Natural;
      View_Height      : Natural) return Pixel_Size;

   --  Validate a Kitty query without retaining decoded pixels.  Local media
   --  is loaded under the same access policy and byte limit as transmission.
   function Validate_Kitty_Query
     (Header        : Terminal.App.Graphics.Graphics_Header;
      Text          : String;
      Policy        : Terminal.App.Graphics_Transport.Access_Policy;
      Maximum_Bytes : Positive)
      return Terminal.Core.Kitty_Graphics_Result_Code;
end Terminal.App.Image_Ingestion;
