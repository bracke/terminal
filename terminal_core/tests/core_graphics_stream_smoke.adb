with AUnit.Assertions;
with Smoke_Case_Failures;
with Terminal.Common.Bytes;
with Terminal.Core;

procedure Core_Graphics_Stream_Smoke is
   use AUnit.Assertions;
   use Terminal.Common.Bytes;
   use type Terminal.Common.Code_Point;
   use type Terminal.Core.Feed_Status;
   use type Terminal.Core.Graphics_Protocol_Kind;
   use type Terminal.Core.Graphics_Stream_ID;
   use type Terminal.Core.Graphics_ID;
   use type Terminal.Core.Graphics_Screen_Generation;
   use type Terminal.Core.Graphics_Event_Sequence;
   use type Terminal.Core.Graphics_Resource_Limits;
   use type Terminal.Core.Initialize_Status;
   use type Terminal.Core.Resize_Status;

   function To_Bytes (Text : String) return Byte_Array is
      Result : Byte_Array (1 .. Text'Length);
   begin
      for I in Text'Range loop
         Result (I - Text'First + 1) := Byte (Character'Pos (Text (I)));
      end loop;
      return Result;
   end To_Bytes;

   function Repeat_Char (Ch : Character; Count : Natural) return String is
      Result : String (1 .. Count);
   begin
      Result := (others => Ch);
      return Result;
   end Repeat_Char;

   procedure Feed_Text
     (Target : in out Terminal.Core.Terminal;
      Text   : String)
   is
      Status : Terminal.Core.Feed_Status;
   begin
      Terminal.Core.Feed (Target, To_Bytes (Text), Status);
      Assert (Status = Terminal.Core.Ok, "graphics stream feed");
   end Feed_Text;

   function Kitty_Completion
     (Code          : Terminal.Core.Graphics_Completion_Code;
      Image_ID      : Terminal.Core.Graphics_ID := 0;
      Image_Number  : Terminal.Core.Graphics_ID := 0;
      Placement_ID  : Terminal.Core.Graphics_ID := 0;
      Quiet         : Natural := 0;
      Respond       : Boolean := True) return Terminal.Core.Graphics_Completion
   is
     (Code => Code,
      Kitty_Response =>
        (Present            => True,
         Image_ID           => Image_ID,
         Image_Number       => Image_Number,
         Has_Image_Number   => Image_Number /= 0,
         Placement_ID       => Placement_ID,
         Has_Placement_ID   => Placement_ID /= 0,
         Quiet              => Quiet,
         Respond            => Respond),
      others => <>);

   procedure Complete_Kitty_Query
     (Target   : in out Terminal.Core.Terminal;
      Image_ID : Terminal.Core.Graphics_ID;
      Code     : Terminal.Core.Graphics_Completion_Code;
      Quiet    : Natural := 0;
      Placement_ID : Terminal.Core.Graphics_ID := 0)
   is
      Event : Terminal.Core.Graphics_Event;
   begin
      Terminal.Core.Peek_Graphics_Event (Target, Event);
      Assert
        (Event.Pending and then Event.Protocol = Terminal.Core.Kitty_Graphics,
         "Kitty query should be queued for backend validation");
      Terminal.Core.Complete_Graphics_Event
        (Target,
         Event,
         Kitty_Completion
           (Code, Image_ID, Placement_ID => Placement_ID, Quiet => Quiet));
   end Complete_Kitty_Query;

   procedure Drain_And_Assert
     (Target     : in out Terminal.Core.Terminal;
      Expected   : String;
      Label_Text : String)
   is
      Buffer : Byte_Array (1 .. 7);
      Event  : Terminal.Core.Graphics_Event;
      Last   : Natural;
      Done   : Boolean := False;
      Offset : Natural := 0;
      Pending_Before : constant Natural :=
        Terminal.Core.Pending_Graphics_Event_Count (Target);
   begin
      while not Done loop
         Terminal.Core.Read_Graphics_Event
           (Target, Event, Buffer, Last, Done);
         Assert (Event.Pending, Label_Text & " pending");
         Assert
           (Event.Protocol = Terminal.Core.Kitty_Graphics,
            Label_Text & " protocol");
         Assert
           (Event.Payload_Length = Expected'Length,
            Label_Text & " payload length");
         for I in 1 .. Last loop
            Offset := Offset + 1;
            Assert
              (Buffer (Buffer'First + I - 1) =
                 Byte (Character'Pos (Expected (Expected'First + Offset - 1))),
               Label_Text & " payload byte" & Natural'Image (Offset));
         end loop;
      end loop;
      Assert (Offset = Expected'Length, Label_Text & " drained length");
      Assert
        (Terminal.Core.Pending_Graphics_Event_Count (Target) = Pending_Before,
         Label_Text & " remains pending until explicit acknowledgement");
      Terminal.Core.Discard_Graphics_Event (Target);
   end Drain_And_Assert;

   procedure Assert_Response
     (Target     : in out Terminal.Core.Terminal;
      Expected   : String;
      Label_Text : String)
   is
      Buffer : Byte_Array (1 .. 1024);
      Last   : Natural;
   begin
      Assert
        (Terminal.Core.Pending_Response_Length (Target) = Expected'Length,
         Label_Text & " response length");
      Terminal.Core.Read_Response (Target, Buffer, Last);
      Assert (Last = Expected'Length, Label_Text & " read length");
      for I in 1 .. Last loop
         Assert
           (Buffer (I) = Byte (Character'Pos (Expected (Expected'First + I - 1))),
            Label_Text & " byte" & Natural'Image (I));
      end loop;
   end Assert_Response;
   procedure Queue_Cases is separate;
   procedure Response_Cases is separate;
   procedure Transaction_Cases is separate;
   procedure Continuation_Cases is separate;
   procedure Screen_Cases is separate;
   procedure Limit_Cases is separate;
   procedure Reset_Cases is separate;
begin
   Queue_Cases;
   Response_Cases;
   Transaction_Cases;
   Continuation_Cases;
   Screen_Cases;
   Limit_Cases;
   Reset_Cases;
end Core_Graphics_Stream_Smoke;
