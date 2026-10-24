with Terminal.App.Render_Model;
with Terminal.App.Image_Store;

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
end Terminal.App.Image_Ingestion;
