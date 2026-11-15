private package Terminal.Core.Graphics_Runtime is
   type Event_Context is record
      Stream_ID            : Graphics_Stream_ID;
      Transaction          : Graphics_Transaction_Generation;
      Alternate_Screen     : Boolean;
      Screen_Generation    : Graphics_Screen_Generation;
      Scroll_Sequence      : Graphics_Scroll_Sequence;
      Sixel_Private_Colors : Boolean;
      Row                  : Positive;
      Col                  : Positive;
   end record;

   type Enqueue_Result is
     (Event_Enqueued, Event_Queue_Limit, Event_Allocation_Failure);

   type Limit_Reconcile_Result is record
      Transfer_Discarded : Boolean := False;
      Deferred_Discarded : Boolean := False;
      Kitty_Discarded    : Boolean := False;
      Multipart_Discarded : Boolean := False;
      Dropped_Events     : Natural := 0;
   end record;

   procedure Clear_Deferred_Input (State : in out Graphics_Runtime_State);
   function Append_Deferred_Input
     (State : in out Graphics_Runtime_State;
      Data  : Core_Byte_Array) return Boolean;
   procedure Take_Deferred_Input
     (State  : in out Graphics_Runtime_State;
      Data   : out Core_Byte_Array_Access;
      Length : out Natural);
   procedure Release_Byte_Array (Data : in out Core_Byte_Array_Access);
   procedure Clear_Graphics_Transfer (State : in out Graphics_Runtime_State);
   function Append_Transfer_Character
     (State : in out Graphics_Runtime_State;
      Ch    : Standard.Character) return Boolean;
   procedure Clear_Kitty_Chunk (State : in out Graphics_Runtime_State);
   function Append_Kitty_Chunk_Data
     (State : in out Graphics_Runtime_State;
      Text  : String) return Boolean;
   function Apply_Kitty_Chunk_Quiet
     (State : in out Graphics_Runtime_State;
      Quiet : Natural) return Boolean;
   procedure Advance_Graphics_Transaction
     (State : in out Graphics_Runtime_State);
   procedure Clear_ITerm2_Multipart (State : in out Graphics_Runtime_State);
   function Append_ITerm2_Multipart
     (State : in out Graphics_Runtime_State; Text : String) return Boolean;
   procedure Enqueue_Event
     (State     : in out Graphics_Runtime_State;
      Protocol  : Graphics_Protocol_Kind;
      Context   : Event_Context;
      Payload   : String;
      Cancelled : Boolean;
      Result    : out Enqueue_Result);
   procedure Apply_Limits
     (State  : in out Graphics_Runtime_State;
      Limits : Graphics_Resource_Limits;
      Result : out Limit_Reconcile_Result);
   procedure Clear_Graphics_Events (State : in out Graphics_Runtime_State);
   function Kitty_Field_Value
     (Payload : String; Key : Standard.Character) return String;
   function Kitty_Command_Blocks_Input
     (State : Graphics_Runtime_State; Payload : String) return Boolean;
   function ITerm2_Command_Blocks_Input (Payload : String) return Boolean;
   procedure Drop_Graphics_Head (State : in out Graphics_Runtime_State);
   procedure Refresh_Last_Event (State : in out Graphics_Runtime_State);
   procedure Refresh_Graphics_Input_Block
     (State : in out Graphics_Runtime_State);
end Terminal.Core.Graphics_Runtime;
