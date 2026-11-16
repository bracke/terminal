package body Terminal.App.Platform_Clipboard is
   function Primary_Available return Boolean is (False);

   procedure Set_Primary
     (Text   : String;
      Status : out Operation_Status)
   is
      pragma Unreferenced (Text);
   begin
      Status := Unavailable;
   end Set_Primary;

   function Primary_Text
     (Status : out Operation_Status) return String is
   begin
      Status := Unavailable;
      return "";
   end Primary_Text;
end Terminal.App.Platform_Clipboard;
