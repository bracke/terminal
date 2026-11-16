package Terminal.App.Platform_Clipboard is
   type Operation_Status is (Ok, Unavailable, Failed, Truncated);

   function Primary_Available return Boolean;

   procedure Set_Primary
     (Text   : String;
      Status : out Operation_Status);

   function Primary_Text
     (Status : out Operation_Status) return String;
end Terminal.App.Platform_Clipboard;
