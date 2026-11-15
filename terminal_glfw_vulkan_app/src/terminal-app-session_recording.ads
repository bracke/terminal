with Ada.Text_IO;
with Ada.Real_Time;
with Terminal.App.Queues;
with Terminal.Core;

package Terminal.App.Session_Recording is
   type State is limited private;
   type IO_Status is
     (Ok, Not_Recording, Invalid_Path, Invalid_Format, IO_Error);

   procedure Start
     (Item   : in out State;
      Path   : String;
      Rows   : Positive;
      Cols   : Positive;
      Status : out IO_Status);
   procedure Stop (Item : in out State; Status : out IO_Status);
   function Active (Item : State) return Boolean;
   procedure Record_Output
     (Item    : in out State;
      Stream  : Terminal.Core.Graphics_Stream_ID;
      Chunk   : Terminal.App.Queues.Byte_Chunk);
   procedure Replay
     (Path   : String;
      Sink   : not null access procedure
        (Stream  : Terminal.Core.Graphics_Stream_ID;
         Chunk   : Terminal.App.Queues.Byte_Chunk);
      Status : out IO_Status);
   procedure Export_Transcript
     (Core   : Terminal.Core.Terminal;
      Path   : String;
      Status : out IO_Status);
   function Status_Label (Item : State) return String;

private
   type State is limited record
      File       : Ada.Text_IO.File_Type;
      Is_Active  : Boolean := False;
      Started_At : Ada.Real_Time.Time := Ada.Real_Time.Time_First;
      Events     : Natural := 0;
   end record;
end Terminal.App.Session_Recording;
