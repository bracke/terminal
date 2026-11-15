private package Terminal.Core.Graphics_Events is
   procedure Resume_Deferred_Input (T : in out Terminal);
   function Take_Deferred_Feed_Status
     (T : in out Terminal) return Feed_Status;
   procedure Peek
     (T     : Terminal;
      Event : out Graphics_Event);
   function Payload
     (T     : Terminal;
      Event : Graphics_Event) return String;
   procedure Visit_Payload
     (T       : Terminal;
      Event   : Graphics_Event;
      Process : not null access procedure (Payload : String);
      Visited : out Boolean);
   procedure Discard (T : in out Terminal);
   procedure Read
     (T            : in out Terminal;
      Event        : out Graphics_Event;
      Buffer       : out Core_Byte_Array;
      Last         : out Natural;
      End_Of_Event : out Boolean);
end Terminal.Core.Graphics_Events;
