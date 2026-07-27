with Terminal.App.Queues;
with Terminal.Core;

package Terminal.App.Clipboard_OSC52 is
   Max_Query_Response_Frame_Bytes : constant := 9;
   Max_Query_Text_Bytes : constant :=
     ((Terminal.App.Queues.Max_Chunk_Length - Max_Query_Response_Frame_Bytes) / 4) * 3;
   Max_Status_Label_Length : constant := 64;

   type Target_Store is private;
   type Target_Capability is record
      Native_Backing    : Boolean := False;
      App_Local_Backing : Boolean := False;
   end record;

   function Capability
     (Target : Terminal.Core.Clipboard_Target) return Target_Capability;
   function Status_Label
     (Target : Terminal.Core.Clipboard_Target) return String;

   procedure Store
     (State  : in out Target_Store;
      Target : Terminal.Core.Clipboard_Target;
      Text   : String);

   procedure Store_Local_Selection
     (State : in out Target_Store;
      Text  : String);

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
