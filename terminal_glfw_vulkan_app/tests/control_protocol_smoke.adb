with AUnit.Assertions;
with Terminal.App.Control_Protocol;

procedure Control_Protocol_Smoke is
   use AUnit.Assertions;
   package Control renames Terminal.App.Control_Protocol;
   use type Control.Command_Kind;
   use type Control.Parse_Status;
   Value : Control.Request;
   Status : Control.Parse_Status;

   procedure Expect
     (Text : String;
      Kind : Control.Command_Kind)
   is
   begin
      Control.Parse (Text, Value, Status);
      Assert (Status = Control.Parsed, Text & " should parse");
      Assert (Control.Kind (Value) = Kind, Text & " command kind");
   end Expect;
begin
   Expect ("ping", Control.Ping);
   Expect ("list", Control.List_Sessions);
   Expect ("new-tab", Control.New_Tab);
   Expect ("close", Control.Close_Session);
   Expect ("split horizontal", Control.Split_Horizontal);
   Expect ("split vertical", Control.Split_Vertical);
   Expect ("send printf hello world", Control.Send_Text);
   Assert (Control.Payload (Value) = "printf hello world", "send payload");
   Expect ("set-title build output", Control.Set_Title);
   Expect ("set-theme high-contrast", Control.Set_Theme);
   Expect ("reload-config", Control.Reload_Config);
   Expect ("get-text", Control.Get_Text);
   Expect ("read-only on", Control.Set_Read_Only);
   Assert (Control.Enabled (Value), "read-only on flag");
   Expect ("read-only off", Control.Set_Read_Only);
   Assert (not Control.Enabled (Value), "read-only off flag");
   Expect ("protected-input on", Control.Set_Protected_Input);
   Assert (Control.Enabled (Value), "protected-input on flag");
   Expect ("protected-input off", Control.Set_Protected_Input);
   Assert (not Control.Enabled (Value), "protected-input off flag");
   Expect ("show", Control.Show_Window);
   Expect ("hide", Control.Hide_Window);
   Expect ("toggle", Control.Toggle_Window);
   Expect ("quit", Control.Quit);

   Expect ("activate 3", Control.Activate_Session);
   Assert (Control.Index (Value) = 3, "activate index");

   Control.Parse ("activate 0", Value, Status);
   Assert (Status = Control.Invalid_Argument, "zero session rejected");
   Control.Parse ("split diagonal", Value, Status);
   Assert (Status = Control.Invalid_Argument, "invalid split rejected");
   Control.Parse ("send", Value, Status);
   Assert (Status = Control.Missing_Argument, "missing send text rejected");
   Control.Parse ("send x" & ASCII.LF & "y", Value, Status);
   Assert (Status = Control.Control_Character, "control byte rejected");
   Control.Parse ("unknown", Value, Status);
   Assert (Status = Control.Unknown_Command, "unknown command rejected");
end Control_Protocol_Smoke;
