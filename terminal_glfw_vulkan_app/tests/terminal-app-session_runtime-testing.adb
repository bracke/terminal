with Ada.Strings.Unbounded;
with Terminal.Common.Bytes;
with Terminal.Core;

package body Terminal.App.Session_Runtime.Testing is
   use type Terminal.Core.Feed_Status;

   procedure Queue_Deferred_Parser_Recovery (R : in out Runtime) is
      Text : constant String :=
        ASCII.ESC & "_Ga=p,i=1" & ASCII.ESC & "\" & ASCII.ESC & "%x";
      Data : Terminal.Common.Bytes.Byte_Array (1 .. Text'Length);
      Status : Terminal.Core.Feed_Status;
   begin
      if R.T = null then
         raise Program_Error with "runtime core is unavailable";
      end if;
      for I in Text'Range loop
         Data (I - Text'First + 1) :=
           Terminal.Common.Bytes.Byte (Standard.Character'Pos (Text (I)));
      end loop;
      Terminal.Core.Feed (R.T.all, Data, Status);
      if Status /= Terminal.Core.Ok
        or else Terminal.Core.Pending_Graphics_Event_Count (R.T.all) = 0
      then
         raise Program_Error with "failed to prepare deferred parser recovery";
      end if;
      Terminal.Core.Discard_Graphics_Event (R.T.all);
   end Queue_Deferred_Parser_Recovery;

   procedure Raise_Storage_Error
     (Pending   : out Ada.Strings.Unbounded.Unbounded_String;
      Text      : String;
      Bracketed : Boolean)
   is
      pragma Unreferenced (Text, Bracketed);
   begin
      Pending := Ada.Strings.Unbounded.Null_Unbounded_String;
      raise Storage_Error with "injected paste construction failure";
   end Raise_Storage_Error;

   procedure Write_Paste_With_Construction_Failure
     (R         : in out Runtime;
      Text      : String;
      Bracketed : Boolean;
      Status    : out Terminal.App.PTY_Write.Write_All_Status)
   is
   begin
      Write_Paste_With_Builder
        (R, Text, Bracketed, Status, Raise_Storage_Error'Access);
   end Write_Paste_With_Construction_Failure;
end Terminal.App.Session_Runtime.Testing;
