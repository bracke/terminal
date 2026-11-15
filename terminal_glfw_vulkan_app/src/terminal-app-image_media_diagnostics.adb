package body Terminal.App.Image_Media_Diagnostics is
   procedure Replace_Identifier
     (Target     : in out Terminal.App.Image_Media.Decode_Diagnostic;
      Identifier : String)
   is
      Used : constant Natural := Natural'Min
        (Identifier'Length,
         Terminal.App.Image_Media.Max_Diagnostic_Identifier_Length);
   begin
      Target.Identifier := (others => ASCII.NUL);
      Target.Identifier_Length := Used;
      if Used > 0 then
         Target.Identifier (1 .. Used) :=
           Identifier (Identifier'First .. Identifier'First + Used - 1);
      end if;
   end Replace_Identifier;

   procedure Initialize
     (Target     : out Terminal.App.Image_Media.Decode_Diagnostic;
      Present    : Boolean;
      Identifier : String) is
   begin
      Target := (others => <>);
      Target.Present := Present;
      Replace_Identifier (Target, Identifier);
   end Initialize;
end Terminal.App.Image_Media_Diagnostics;
