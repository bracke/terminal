with Ada.Command_Line;
with Interfaces.C;
with System;
with System.Storage_Elements;
with Terminal.Common.UTF8;

package body Terminal.App.Platform_Launcher is
   pragma Linker_Options ("-lshell32");

   use type System.Storage_Elements.Integer_Address;

   subtype UTF16_Unit is Terminal.Common.UTF8.UTF16_Unit;
   subtype UTF16_Array is Terminal.Common.UTF8.UTF16_Array;

   function Shell_Execute
     (Window     : System.Address;
      Operation  : access constant UTF16_Unit;
      File_Name  : access constant UTF16_Unit;
      Parameters : System.Address;
      Directory  : System.Address;
      Show       : Interfaces.C.int) return System.Address
     with Import, Convention => Stdcall, External_Name => "ShellExecuteW";

   procedure Launch_Program
     (Program : String;
      URI     : String;
      Status  : out Launch_Status)
   is
      pragma Unreferenced (Program);
      Operation : aliased UTF16_Array (0 .. 4) :=
        (UTF16_Unit (Character'Pos ('o')),
         UTF16_Unit (Character'Pos ('p')),
         UTF16_Unit (Character'Pos ('e')),
         UTF16_Unit (Character'Pos ('n')),
         0);
      Target    : aliased UTF16_Array (0 .. URI'Length);
      Target_Length : Natural;
      Valid : Boolean;
      Result    : System.Address;
   begin
      Terminal.Common.UTF8.Decode_UTF16
        (URI, Target, Target_Length, Valid);
      if not Valid then
         Status := Launch_Failed;
         return;
      end if;
      Result :=
        Shell_Execute
          (System.Null_Address,
           Operation (Operation'First)'Access,
           Target (Target'First)'Access,
           System.Null_Address,
           System.Null_Address,
           1);
      Status :=
        (if System.Storage_Elements.To_Integer (Result) > 32
         then Opened
         else Launch_Failed);
   exception
      when others =>
         Status := Launch_Failed;
   end Launch_Program;

   procedure Poll is null;

   function Pending_Launch_Count return Natural is (0);

   function Child_Tracking_Available return Boolean is (False);

   procedure Dispatch_URI
     (Preferred_Program : String;
      Fallback_Program  : String;
      URI               : String;
      Status            : out Launch_Status;
      Start             : not null access procedure
        (Program : String;
         URI     : String;
         Status  : out Launch_Status)) is separate;

   procedure Open_URI
     (URI    : String;
      Status : out Launch_Status) is
   begin
      Dispatch_URI ("shell", "", URI, Status, Launch_Program'Access);
   end Open_URI;

   procedure Show_Notification
     (Title  : String;
      Message : String;
      Status : out Launch_Status)
   is
      function PowerShell_Quote (Value : String) return String is
         Result : String (1 .. Value'Length * 2);
         Last : Natural := 0;
      begin
         for Ch of Value loop
            Last := Last + 1;
            Result (Last) := Ch;
            if Ch = ''' then
               Last := Last + 1;
               Result (Last) := ''';
            end if;
         end loop;
         return (if Last = 0 then "" else Result (1 .. Last));
      end PowerShell_Quote;

      function Encode_Command (Value : String) return String is
         Alphabet : constant String :=
           "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
         Wide : UTF16_Array (0 .. Value'Length);
         Wide_Length : Natural;
         Valid : Boolean;
      begin
         Terminal.Common.UTF8.Decode_UTF16
           (Value, Wide, Wide_Length, Valid);
         if not Valid or else Wide_Length = 0 then
            return "";
         end if;
         declare
            Byte_Count : constant Natural := Wide_Length * 2;
            Result : String (1 .. ((Byte_Count + 2) / 3) * 4);
            Source : Natural := 0;
            Target : Positive := 1;
            B1, B2, B3 : Natural;
            Remaining : Natural;
            function Byte_At (Index : Natural) return Natural is
               Unit : constant Natural := Natural (Wide (Index / 2));
            begin
               return (if Index mod 2 = 0 then Unit mod 256 else Unit / 256);
            end Byte_At;
         begin
            while Source < Byte_Count loop
               Remaining := Byte_Count - Source;
               B1 := Byte_At (Source);
               B2 := (if Remaining > 1 then Byte_At (Source + 1) else 0);
               B3 := (if Remaining > 2 then Byte_At (Source + 2) else 0);
               Result (Target) := Alphabet (B1 / 4 + 1);
               Result (Target + 1) := Alphabet ((B1 mod 4) * 16 + B2 / 16 + 1);
               Result (Target + 2) :=
                 (if Remaining > 1
                  then Alphabet ((B2 mod 16) * 4 + B3 / 64 + 1)
                  else '=');
               Result (Target + 3) :=
                 (if Remaining > 2 then Alphabet (B3 mod 64 + 1) else '=');
               Source := Source + 3;
               Target := Target + 4;
            end loop;
            return Result;
         end;
      end Encode_Command;

      Effective_Title : constant String :=
        (if Title = "" then "Bracke Terminal" else Title);
      Effective_Message : constant String :=
        (if Message = "" then Title else Message);
      Script : constant String :=
        "$t=[Security.SecurityElement]::Escape('"
          & PowerShell_Quote (Effective_Title)
          & "');$m=[Security.SecurityElement]::Escape('"
          & PowerShell_Quote (Effective_Message)
          & "');$x=[Windows.Data.Xml.Dom.XmlDocument,Windows.Data.Xml.Dom."
          & "XmlDocument,ContentType=WindowsRuntime]::new();$x.LoadXml('"
          & "<toast><visual><binding template=""ToastGeneric""><text>'+$t+"
          & "'</text><text>'+$m+'</text></binding></visual></toast>');"
          & "$n=[Windows.UI."
          & "Notifications.ToastNotification,Windows.UI.Notifications,"
          & "ContentType=WindowsRuntime]::new($x);[Windows.UI.Notifications."
          & "ToastNotificationManager]::CreateToastNotifier('Bracke Terminal')"
          & ".Show($n)";
      Encoded : constant String := Encode_Command (Script);
      Parameters : constant String :=
        "-NoProfile -NonInteractive -WindowStyle Hidden -EncodedCommand "
          & Encoded;
      Operation : aliased UTF16_Array (0 .. 4) :=
        (UTF16_Unit (Character'Pos ('o')),
         UTF16_Unit (Character'Pos ('p')),
         UTF16_Unit (Character'Pos ('e')),
         UTF16_Unit (Character'Pos ('n')), 0);
      Program : constant String := "powershell.exe";
      Program_Wide : aliased UTF16_Array (0 .. Program'Length);
      Parameters_Wide : aliased UTF16_Array (0 .. Parameters'Length);
      Program_Length, Parameters_Length : Natural;
      Program_Valid, Parameters_Valid : Boolean;
      Result : System.Address;
   begin
      if Effective_Message = "" or else Encoded = "" then
         Status := Launch_Failed;
         return;
      end if;
      Terminal.Common.UTF8.Decode_UTF16
        (Program, Program_Wide, Program_Length, Program_Valid);
      Terminal.Common.UTF8.Decode_UTF16
        (Parameters, Parameters_Wide, Parameters_Length, Parameters_Valid);
      if not Program_Valid or else not Parameters_Valid then
         Status := Launch_Failed;
         return;
      end if;
      Result := Shell_Execute
        (System.Null_Address,
         Operation (0)'Access,
         Program_Wide (0)'Access,
         Parameters_Wide (0)'Address,
         System.Null_Address,
         0);
      Status :=
        (if System.Storage_Elements.To_Integer (Result) > 32
         then Opened else Launcher_Unavailable);
   exception
      when others => Status := Launch_Failed;
   end Show_Notification;

   procedure Open_Window
     (Workspace_Path : String;
      Status         : out Launch_Status)
   is
      Operation : aliased UTF16_Array (0 .. 4) :=
        (UTF16_Unit (Character'Pos ('o')),
         UTF16_Unit (Character'Pos ('p')),
         UTF16_Unit (Character'Pos ('e')),
         UTF16_Unit (Character'Pos ('n')), 0);
      Program : constant String := Ada.Command_Line.Command_Name;
      Argument : constant String := "--workspace=" & Workspace_Path;
      Program_Wide : aliased UTF16_Array (0 .. Program'Length);
      Argument_Wide : aliased UTF16_Array (0 .. Argument'Length);
      Program_Length, Argument_Length : Natural;
      Program_Valid, Argument_Valid : Boolean;
      Result : System.Address;
   begin
      Terminal.Common.UTF8.Decode_UTF16
        (Program, Program_Wide, Program_Length, Program_Valid);
      Terminal.Common.UTF8.Decode_UTF16
        (Argument, Argument_Wide, Argument_Length, Argument_Valid);
      if Workspace_Path = "" or else not Program_Valid or else not Argument_Valid then
         Status := Launch_Failed;
         return;
      end if;
      Result := Shell_Execute
        (System.Null_Address, Operation (0)'Access, Program_Wide (0)'Access,
         Argument_Wide (0)'Address, System.Null_Address, 1);
      Status :=
        (if System.Storage_Elements.To_Integer (Result) > 32
         then Opened else Launch_Failed);
   exception
      when others => Status := Launch_Failed;
   end Open_Window;
end Terminal.App.Platform_Launcher;
