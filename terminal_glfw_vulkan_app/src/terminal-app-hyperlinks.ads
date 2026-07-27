with Terminal.App.Selection;
with Terminal.Core;

package Terminal.App.Hyperlinks is
   Max_Command_Length : constant := 1024;
   Max_Hover_Title_Length : constant := 512;
   Max_Link_Label_Length : constant := 256;
   Max_Status_Label_Length : constant := Max_Link_Label_Length + 18;

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

   function Same_Link
     (Left  : Terminal.Core.Hyperlink;
      Right : Terminal.Core.Hyperlink) return Boolean;

   function Supported_URI (URI : String) return Boolean;

   function Open_Command (URI : String) return String;
   function Link_Label (Link : Terminal.Core.Hyperlink) return String;
   function Status_Label (Link : Terminal.Core.Hyperlink) return String;
   function Activation_Status_Label (Status : Activation_Status) return String;
   function Hover_Title
     (Base_Title : String;
      Link       : Terminal.Core.Hyperlink) return String;

   procedure Activate
     (Link   : Terminal.Core.Hyperlink;
      Status : out Activation_Status);
end Terminal.App.Hyperlinks;
