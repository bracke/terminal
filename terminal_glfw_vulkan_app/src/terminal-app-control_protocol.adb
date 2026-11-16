with Ada.Characters.Handling;
with Ada.Strings;
with Ada.Strings.Fixed;

package body Terminal.App.Control_Protocol is
   function Trimmed (Text : String) return String is
     (Ada.Strings.Fixed.Trim (Text, Ada.Strings.Both));

   function Kind (Value : Request) return Command_Kind is (Value.Command);
   function Index (Value : Request) return Positive is (Value.Number);
   function Enabled (Value : Request) return Boolean is (Value.Flag);

   function Payload (Value : Request) return String is
     (if Value.Length = 0 then "" else Value.Text (1 .. Value.Length));

   procedure Store
     (Value  : in out Request;
      Text   : String;
      Status : out Parse_Status)
   is
   begin
      if Text'Length > Max_Payload_Length then
         Status := Payload_Too_Long;
         return;
      end if;
      for Ch of Text loop
         if Character'Pos (Ch) < 32 and then Ch /= ASCII.HT then
            Status := Control_Character;
            return;
         end if;
      end loop;
      Value.Length := Text'Length;
      if Text'Length > 0 then
         Value.Text (1 .. Text'Length) := Text;
      end if;
      Status := Parsed;
   end Store;

   procedure Parse
     (Text   : String;
      Value  : out Request;
      Status : out Parse_Status)
   is
   begin
      Value := (others => <>);
      if Text'Length > Max_Request_Length then
         Status := Request_Too_Long;
         return;
      end if;
      declare
         Input : constant String := Trimmed (Text);
         Space : constant Natural := Ada.Strings.Fixed.Index (Input, " ");
         Name : constant String := Ada.Characters.Handling.To_Lower
           ((if Space = 0 then Input else Input (Input'First .. Space - 1)));
         Argument : constant String :=
           (if Space = 0 then "" else Trimmed (Input (Space + 1 .. Input'Last)));
      begin
         if Input = "" then
            Status := Empty_Request;
         elsif Name = "ping" and then Argument = "" then
            Value.Command := Ping;
            Status := Parsed;
         elsif Name = "list" and then Argument = "" then
            Value.Command := List_Sessions;
            Status := Parsed;
         elsif Name = "activate" then
            if Argument = "" then
               Status := Missing_Argument;
            else
               begin
                  Value.Number := Positive'Value (Argument);
                  Value.Command := Activate_Session;
                  Status := Parsed;
               exception
                  when Constraint_Error => Status := Invalid_Argument;
               end;
            end if;
         elsif Name = "new-tab" and then Argument = "" then
            Value.Command := New_Tab;
            Status := Parsed;
         elsif Name = "close" and then Argument = "" then
            Value.Command := Close_Session;
            Status := Parsed;
         elsif Name = "split" then
            if Ada.Characters.Handling.To_Lower (Argument) = "horizontal" then
               Value.Command := Split_Horizontal;
               Status := Parsed;
            elsif Ada.Characters.Handling.To_Lower (Argument) = "vertical" then
               Value.Command := Split_Vertical;
               Status := Parsed;
            elsif Argument = "" then
               Status := Missing_Argument;
            else
               Status := Invalid_Argument;
            end if;
         elsif Name in "send" | "set-title" | "set-theme" then
            if Argument = "" then
               Status := Missing_Argument;
            else
               Value.Command :=
                 (if Name = "send" then Send_Text
                  elsif Name = "set-title" then Set_Title
                  else Set_Theme);
               Store (Value, Argument, Status);
            end if;
         elsif Name = "reload-config" and then Argument = "" then
            Value.Command := Reload_Config;
            Status := Parsed;
         elsif Name = "get-text" and then Argument = "" then
            Value.Command := Get_Text;
            Status := Parsed;
         elsif Name = "read-only" or else Name = "protected-input" then
            if Ada.Characters.Handling.To_Lower (Argument) = "on" then
               Value.Command :=
                 (if Name = "read-only" then Set_Read_Only
                  else Set_Protected_Input);
               Value.Flag := True;
               Status := Parsed;
            elsif Ada.Characters.Handling.To_Lower (Argument) = "off" then
               Value.Command :=
                 (if Name = "read-only" then Set_Read_Only
                  else Set_Protected_Input);
               Value.Flag := False;
               Status := Parsed;
            elsif Argument = "" then
               Status := Missing_Argument;
            else
               Status := Invalid_Argument;
            end if;
         elsif Name = "show" and then Argument = "" then
            Value.Command := Show_Window;
            Status := Parsed;
         elsif Name = "hide" and then Argument = "" then
            Value.Command := Hide_Window;
            Status := Parsed;
         elsif Name = "toggle" and then Argument = "" then
            Value.Command := Toggle_Window;
            Status := Parsed;
         elsif Name = "quit" and then Argument = "" then
            Value.Command := Quit;
            Status := Parsed;
         else
            Status := Unknown_Command;
         end if;
      end;
   end Parse;

   function Status_Label (Status : Parse_Status) return String is
     (case Status is
         when Parsed          => "ok",
         when Empty_Request   => "empty request",
         when Request_Too_Long => "request too long",
         when Unknown_Command => "unknown command",
         when Missing_Argument => "missing argument",
         when Invalid_Argument => "invalid argument",
         when Payload_Too_Long => "payload too long",
         when Control_Character => "control character rejected");
end Terminal.App.Control_Protocol;
