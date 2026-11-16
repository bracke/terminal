with Ada.Real_Time;
with Terminal.Common.Bytes;
with Terminal.Core;
with Terminal.App.Queues;
with Terminal.App.Sessions;

package Terminal.App.Output_Triggers is
   Max_Triggers : constant := 8;
   Max_Name_Length : constant := 32;
   Max_Pattern_Length : constant := 96;
   Cooldown : constant Duration := 5.0;

   type Registry is private;
   procedure Apply
     (Item     : in out Registry;
      Name     : String;
      Pattern  : String;
      Accepted : out Boolean);
   function Count (Item : Registry) return Natural;
   function Name (Item : Registry; Index : Positive) return String;
   function Pattern (Item : Registry; Index : Positive) return String;

   type Fired_Set is array (Positive range 1 .. Max_Triggers) of Boolean;
   type Detector is limited private;
   procedure Process
     (Item    : in out Detector;
      Rules   : Registry;
      Session : Terminal.App.Sessions.Session_Index;
      Stream  : Terminal.Core.Graphics_Stream_ID;
      Chunk   : Terminal.App.Queues.Byte_Chunk;
      Now     : Ada.Real_Time.Time;
      Fired   : out Fired_Set);
   procedure Reset
     (Item : in out Detector;
      Session : Terminal.App.Sessions.Session_Index);

private
   type Text_Value (Capacity : Positive) is record
      Length : Natural := 0;
      Text : String (1 .. Capacity) := (others => ' ');
   end record;
   subtype Name_Value is Text_Value (Max_Name_Length);
   subtype Pattern_Value is Text_Value (Max_Pattern_Length);
   type Rule is record
      Rule_Name : Name_Value;
      Rule_Pattern : Pattern_Value;
   end record;
   type Rule_Array is array (Positive range 1 .. Max_Triggers) of Rule;
   type Registry is record
      Length : Natural range 0 .. Max_Triggers := 0;
      Rules : Rule_Array := (others => <>);
   end record;

   type History is record
      Data : Terminal.Common.Bytes.Byte_Array (1 .. Max_Pattern_Length) :=
        (others => 0);
      Next : Positive range 1 .. Max_Pattern_Length := 1;
      Seen : Natural := 0;
   end record;
   type Session_History_Array is array
     (Terminal.App.Sessions.Session_Index) of History;
   type Fire_Time_Array is array
     (Terminal.App.Sessions.Session_Index, Positive range 1 .. Max_Triggers) of
       Ada.Real_Time.Time;
   type Stream_ID_Array is array
     (Terminal.App.Sessions.Session_Index) of Terminal.Core.Graphics_Stream_ID;
   type Stream_Valid_Array is array
     (Terminal.App.Sessions.Session_Index) of Boolean;
   type Detector is limited record
      Histories : Session_History_Array := (others => <>);
      Last_Fired : Fire_Time_Array := (others => (others => Ada.Real_Time.Time_First));
      Streams : Stream_ID_Array := (others => 0);
      Stream_Valid : Stream_Valid_Array := (others => False);
   end record;
end Terminal.App.Output_Triggers;
