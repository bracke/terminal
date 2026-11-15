package body Terminal.Core.State_Access is
   use type Dirty_Row_Array_Access;

   function Resource_Limit
     (T : Terminal) return Graphics_Resource_Limits is
     (T.Graphics.Limits);

   function Modes (T : Terminal) return Mode_Snapshot is
     (T.Current_Modes);

   function Diagnostics (T : Terminal) return Diagnostic_Snapshot is
     (T.Diag);

   function Title (T : Terminal) return Title_Text is
     (T.Window_Title);

   function Clipboard (T : Terminal) return Clipboard_Request is
     (T.Clipboard_Data);

   procedure Clear_Clipboard (T : in out Terminal) is
   begin
      T.Clipboard_Data := (others => <>);
   end Clear_Clipboard;

   function Scrollback_Row_Count (T : Terminal) return Natural is
     (T.Scrollback_State.Rows);

   function Pending_Response_Length (T : Terminal) return Natural is
     (T.Responses.Length);

   function Pending_Graphics_Event_Count (T : Terminal) return Natural is
     (T.Graphics.Event_Count);

   function Pending_Graphics_Byte_Count (T : Terminal) return Natural is
     (T.Graphics.Byte_Count);

   procedure Read_Response
     (T      : in out Terminal;
      Buffer : out Common.Bytes.Byte_Array;
      Last   : out Natural)
   is
      Count : constant Natural :=
        Natural'Min (Buffer'Length, T.Responses.Length);
   begin
      Last := Count;
      if Count > 0 then
         for I in 1 .. Count loop
            Buffer (Buffer'First + I - 1) := T.Responses.Bytes (I);
         end loop;
         if Count < T.Responses.Length then
            for I in 1 .. T.Responses.Length - Count loop
               T.Responses.Bytes (I) := T.Responses.Bytes (I + Count);
            end loop;
         end if;
         T.Responses.Length := T.Responses.Length - Count;
      end if;
   end Read_Response;

   procedure Clear_Damage (T : in out Terminal) is
   begin
      if T.Dirty /= null then
         T.Dirty.all := (others => False);
      end if;
   end Clear_Damage;
end Terminal.Core.State_Access;
