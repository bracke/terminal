with Ada.Environment_Variables;
with AUnit.Assertions;
with Terminal.App.Platform_Clipboard;

procedure Platform_Clipboard_Smoke is
   use AUnit.Assertions;
   package Environment renames Ada.Environment_Variables;
   package Clipboard renames Terminal.App.Platform_Clipboard;
   use type Clipboard.Operation_Status;

   Name : constant String := "TERMINAL_DISABLE_NATIVE_PRIMARY";
   Had_Value : constant Boolean := Environment.Exists (Name);
   Previous : constant String :=
     (if Had_Value then Environment.Value (Name) else "");
   Status : Clipboard.Operation_Status;
begin
   Environment.Set (Name, "1");
   Assert
     (not Clipboard.Primary_Available,
      "disabled native primary backend should be unavailable");
   Clipboard.Set_Primary ("must not escape", Status);
   Assert
     (Status = Clipboard.Unavailable,
      "disabled primary set should fail closed without spawning a client");
   declare
      Text : constant String := Clipboard.Primary_Text (Status);
   begin
      Assert
        (Status = Clipboard.Unavailable and then Text = "",
         "disabled primary read should return a bounded empty fallback");
   end;

   if Had_Value then
      Environment.Set (Name, Previous);
   else
      Environment.Clear (Name);
   end if;
end Platform_Clipboard_Smoke;
