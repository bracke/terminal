with Terminal.App.Queues;
with Terminal.Core;

package Terminal.App.Clipboard_OSC52 is
   Max_Query_Text_Bytes : constant := 3_063;

   type Target_Store is private;

   procedure Store
     (State  : in out Target_Store;
      Target : Terminal.Core.Clipboard_Target;
      Text   : String);

   function Text
     (State  : Target_Store;
      Target : Terminal.Core.Clipboard_Target) return String;

   procedure Build_Query_Response
     (Text  : String;
      Chunk : out Terminal.App.Queues.Byte_Chunk);

   procedure Build_Query_Response
     (Target : Terminal.Core.Clipboard_Target;
      Text   : String;
      Chunk  : out Terminal.App.Queues.Byte_Chunk);

private
   subtype Stored_Length is Natural range 0 .. Terminal.Core.Max_Clipboard_Length;
   subtype Stored_Index is Positive range 1 .. Terminal.Core.Max_Clipboard_Length;
   type Stored_Text is record
      Length : Stored_Length := 0;
      Data   : String (Stored_Index) := (others => ' ');
   end record;

   type Target_Store is record
      Primary   : Stored_Text;
      Selection : Stored_Text;
   end record;
end Terminal.App.Clipboard_OSC52;
