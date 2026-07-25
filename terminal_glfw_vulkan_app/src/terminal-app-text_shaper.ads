with Terminal.App.Render_Model;

package Terminal.App.Text_Shaper is
   type Run_Kind is
     (Simple_Glyph,
      Combining_Cluster,
      Joined_Emoji_Cluster,
      Emoji_Modified_Cluster,
      Bidi_Text,
      Complex_Script,
      Ligature_Candidate,
      Invalid_Run);

   type Shape_Status is
     (Ok,
      Needs_Shaping_Backend,
      Invalid_Run);

   function Classify
     (Run : Terminal.App.Render_Model.Text_Run_Command) return Run_Kind;

   function Requires_Backend (Kind : Run_Kind) return Boolean;

   procedure Prepare
     (Run    : in out Terminal.App.Render_Model.Text_Run_Command;
      Status : out Shape_Status);
end Terminal.App.Text_Shaper;
