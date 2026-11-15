with Ada.Finalization;
with Ada.Streams;
with Zlib;

--  Shared checked ownership boundary around a zlib inflate filter.  Format
--  decoders retain their distinct input/output policies while lifecycle,
--  codec exceptions, and stream termination are handled in one place.
private package Terminal.App.Inflate_Filter is
   type Wrapper_Kind is (Zlib_Wrapper, Raw_Deflate);
   type Decoder is limited private;

   procedure Start
     (State   : in out Decoder;
      Wrapper : Wrapper_Kind;
      Success : out Boolean);
   procedure Translate
     (State       : in out Decoder;
      Input       : Ada.Streams.Stream_Element_Array;
      Input_Last  : out Ada.Streams.Stream_Element_Offset;
      Output      : out Ada.Streams.Stream_Element_Array;
      Output_Last : out Ada.Streams.Stream_Element_Offset;
      Success     : out Boolean);
   procedure Finish
     (State       : in out Decoder;
      Output      : out Ada.Streams.Stream_Element_Array;
      Output_Last : out Ada.Streams.Stream_Element_Offset;
      Success     : out Boolean);
   function Ended (State : Decoder) return Boolean;
   procedure Close (State : in out Decoder);

private
   type Lifecycle_State is (Closed, Active, Failed);
   type Decoder is new Ada.Finalization.Limited_Controlled with record
      Filter : Zlib.Filter_Type;
      State  : Lifecycle_State := Closed;
   end record;
   overriding procedure Finalize (State : in out Decoder);
end Terminal.App.Inflate_Filter;
