private package Terminal.Core.State_Access is
   function Resource_Limit
     (T : Terminal) return Graphics_Resource_Limits;
   function Modes (T : Terminal) return Mode_Snapshot;
   function Diagnostics (T : Terminal) return Diagnostic_Snapshot;
   function Title (T : Terminal) return Title_Text;
   function Clipboard (T : Terminal) return Clipboard_Request;
   procedure Clear_Clipboard (T : in out Terminal);
   function Scrollback_Row_Count (T : Terminal) return Natural;
   function Pending_Response_Length (T : Terminal) return Natural;
   function Pending_Graphics_Event_Count (T : Terminal) return Natural;
   function Pending_Graphics_Byte_Count (T : Terminal) return Natural;
   procedure Read_Response
     (T      : in out Terminal;
      Buffer : out Common.Bytes.Byte_Array;
      Last   : out Natural);
   procedure Clear_Damage (T : in out Terminal);
end Terminal.Core.State_Access;
