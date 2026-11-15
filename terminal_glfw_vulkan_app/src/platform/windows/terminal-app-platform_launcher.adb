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
      Status : out Launch_Status) is
      pragma Unreferenced (Title, Message);
   begin
      Status := Launcher_Unavailable;
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
