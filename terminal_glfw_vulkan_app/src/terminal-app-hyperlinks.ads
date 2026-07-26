with Terminal.App.Selection;
with Terminal.Core;

package Terminal.App.Hyperlinks is
   Max_Command_Length : constant := 1024;

   type Activation_Status is
     (Ok,
      No_Link,
      Unsupported_URI,
      Command_Too_Long,
      Launch_Failed);

   function Link_At
     (Snapshot : Terminal.Core.Render_Snapshot;
      Position : Terminal.App.Selection.Cell_Position)
      return Terminal.Core.Hyperlink;

   function Supported_URI (URI : String) return Boolean;

   function Open_Command (URI : String) return String;

   procedure Activate
     (Link   : Terminal.Core.Hyperlink;
      Status : out Activation_Status);
end Terminal.App.Hyperlinks;
