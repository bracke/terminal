with GLFW_Vulkan.Windows;
with Terminal.Core;

package Terminal.App.Accessibility is
   type State is limited private;

   procedure Initialize
     (Item   : in out State;
      Window : GLFW_Vulkan.Windows.Window);
   procedure Publish
     (Item        : in out State;
      Snapshot    : Terminal.Core.Render_Snapshot;
      Width       : Natural;
      Height      : Natural;
      Cell_Width  : Positive;
      Cell_Height : Positive;
      Margin      : Natural;
      Title       : String;
      Status      : String);
   procedure Service (Item : in out State);
   procedure Set_Focused (Item : in out State; Focused : Boolean);
   procedure Finalize (Item : in out State);
   function Status_Label (Item : State) return String;

private
   type Content_Hash is mod 2 ** 64;
   type State is limited record
      Started        : Boolean := False;
      Focused        : Boolean := False;
      Published      : Boolean := False;
      Last_Hash      : Content_Hash := 0;
   end record;
end Terminal.App.Accessibility;
