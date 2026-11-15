package body Terminal.App.Zlib_Inflation is
   use type Ada.Streams.Stream_Element_Offset;

   procedure Close (State : in out Decoder) is
   begin
      Terminal.App.Inflate_Filter.Close (State.Filter);
   end Close;

   overriding procedure Finalize (State : in out Decoder) is
   begin
      Close (State);
   end Finalize;

   procedure Fail
     (State  : in out Decoder;
      Status : Terminal.App.Image_Decode.Status) is
   begin
      State.State := Failed;
      State.Failure_Status := Status;
   end Fail;

   procedure Consume
     (State : in out Decoder;
      Data  : Ada.Streams.Stream_Element_Array;
      Last  : Ada.Streams.Stream_Element_Offset)
   is
      Count : Natural;
   begin
      if Last < Data'First then
         return;
      end if;
      Count := Natural (Last - Data'First + 1);
      if Count > State.Maximum_Length - State.Output_Length then
         Fail (State, Terminal.App.Image_Decode.Decode_Too_Large);
         return;
      end if;
      declare
         procedure Append (Target : in out Terminal.Common.Bytes.Byte_Array) is
         begin
            for I in Data'First .. Last loop
               Target
                 (Target'First + State.Output_Length
                  + Natural (I - Data'First)) :=
                    Terminal.Common.Bytes.Byte (Data (I));
            end loop;
         end Append;
      begin
         State.Output.Modify (Append'Access);
      end;
      State.Output_Length := State.Output_Length + Count;
   end Consume;

   procedure Translate_Input (State : in out Decoder) is
      First : Ada.Streams.Stream_Element_Offset := State.Input'First;
      Last  : constant Ada.Streams.Stream_Element_Offset :=
        State.Input'First
        + Ada.Streams.Stream_Element_Offset (State.Input_Length) - 1;
   begin
      while State.State /= Failed and then First <= Last loop
         declare
            Output : Ada.Streams.Stream_Element_Array
              (1 .. Ada.Streams.Stream_Element_Offset (Buffer_Size));
            Input_Last  : Ada.Streams.Stream_Element_Offset;
            Output_Last : Ada.Streams.Stream_Element_Offset;
            Before      : constant Ada.Streams.Stream_Element_Offset := First;
            Success     : Boolean;
         begin
            Terminal.App.Inflate_Filter.Translate
              (State.Filter,
               State.Input (First .. Last),
               Input_Last,
               Output,
               Output_Last,
               Success);
            if not Success then
               Fail (State, Terminal.App.Image_Decode.Decode_Invalid_Byte);
               exit;
            end if;
            Consume (State, Output, Output_Last);
            exit when State.State = Failed;
            if Input_Last >= First then
               First := Input_Last + 1;
            elsif Output_Last < Output'First then
               Fail (State, Terminal.App.Image_Decode.Decode_Invalid_Byte);
            end if;
            if Terminal.App.Inflate_Filter.Ended (State.Filter) then
               if First <= Last then
                  Fail (State, Terminal.App.Image_Decode.Decode_Trailing_Data);
               end if;
               exit;
            elsif First = Before and then Output_Last < Output'First then
               Fail (State, Terminal.App.Image_Decode.Decode_Invalid_Byte);
            end if;
         end;
      end loop;
      State.Input_Length := 0;
   exception
      when Constraint_Error =>
         Fail (State, Terminal.App.Image_Decode.Decode_Invalid_Byte);
         State.Input_Length := 0;
   end Translate_Input;

   procedure Start
     (State          : in out Decoder;
      Maximum_Length : Natural;
      Exact_Length   : Boolean;
      Status         : out Terminal.App.Image_Decode.Status) is
   begin
      Close (State);
      State.Output.Release;
      State.State := Idle;
      State.Failure_Status := Terminal.App.Image_Decode.Decode_Invalid_Byte;
      State.Output_Length := 0;
      State.Input_Length := 0;
      State.Maximum_Length := Maximum_Length;
      State.Exact_Length := Exact_Length;
      Status := Terminal.App.Image_Decode.Decode_Invalid_Byte;
      if Maximum_Length = 0 then
         return;
      elsif Maximum_Length >
        Terminal.App.Render_Model.Max_Image_Decoded_Data_Length
      then
         Status := Terminal.App.Image_Decode.Decode_Too_Large;
         return;
      end if;
      State.Output.Allocate (Maximum_Length);
      declare
         Success : Boolean;
      begin
         Terminal.App.Inflate_Filter.Start
           (State.Filter, Terminal.App.Inflate_Filter.Zlib_Wrapper, Success);
         if not Success then
            State.Output.Release;
            Status := Terminal.App.Image_Decode.Decode_Invalid_Byte;
            return;
         end if;
      end;
      State.State := Ready;
      Status := Terminal.App.Image_Decode.Decode_Ok;
   exception
      when Storage_Error =>
         Close (State);
         State.Output.Release;
         Status := Terminal.App.Image_Decode.Decode_Allocation_Failed;
   end Start;

   procedure Push
     (State    : in out Decoder;
      Value    : Terminal.Common.Bytes.Byte;
      Continue : in out Boolean) is
   begin
      if State.State /= Ready then
         Continue := False;
         return;
      elsif Terminal.App.Inflate_Filter.Ended (State.Filter) then
         Fail (State, Terminal.App.Image_Decode.Decode_Trailing_Data);
         Continue := False;
         return;
      end if;
      State.Input_Length := State.Input_Length + 1;
      State.Input
        (State.Input'First
         + Ada.Streams.Stream_Element_Offset (State.Input_Length) - 1) :=
           Ada.Streams.Stream_Element (Value);
      if State.Input_Length = Buffer_Size then
         Translate_Input (State);
      end if;
      Continue := State.State = Ready;
   end Push;

   procedure Finish
     (State           : in out Decoder;
      Inflated        : in out Terminal.App.Owned_Image_Data.Owner;
      Inflated_Length : out Natural;
      Status          : out Terminal.App.Image_Decode.Status) is
   begin
      Terminal.App.Owned_Image_Data.Release (Inflated);
      Inflated_Length := 0;
      Status := Terminal.App.Image_Decode.Decode_Invalid_Byte;
      if State.State = Idle then
         return;
      end if;
      if State.Input_Length > 0 and then State.State = Ready then
         Translate_Input (State);
      end if;
      for Pass in 1 .. State.Maximum_Length / Buffer_Size + 4 loop
         exit when State.State = Failed
           or else Terminal.App.Inflate_Filter.Ended (State.Filter);
         declare
            Output : Ada.Streams.Stream_Element_Array
              (1 .. Ada.Streams.Stream_Element_Offset (Buffer_Size));
            Output_Last : Ada.Streams.Stream_Element_Offset;
            Success : Boolean;
         begin
            Terminal.App.Inflate_Filter.Finish
              (State.Filter, Output, Output_Last, Success);
            if not Success then
               Fail (State, Terminal.App.Image_Decode.Decode_Invalid_Byte);
               exit;
            end if;
            Consume (State, Output, Output_Last);
            if State.State /= Failed
              and then Output_Last < Output'First
              and then not Terminal.App.Inflate_Filter.Ended (State.Filter)
            then
               Fail (State, Terminal.App.Image_Decode.Decode_Invalid_Byte);
            end if;
         end;
      end loop;
      if State.State /= Failed
        and then not Terminal.App.Inflate_Filter.Ended (State.Filter)
      then
         Fail (State, Terminal.App.Image_Decode.Decode_Invalid_Byte);
      elsif State.State /= Failed and then State.Output_Length = 0 then
         Fail (State, Terminal.App.Image_Decode.Decode_Invalid_Byte);
      elsif State.State /= Failed
        and then State.Exact_Length
        and then State.Output_Length /= State.Maximum_Length
      then
         Fail (State, Terminal.App.Image_Decode.Decode_Invalid_Byte);
      end if;
      Close (State);
      if State.State = Failed then
         Status := State.Failure_Status;
         State.Output.Release;
         State.State := Idle;
         return;
      end if;
      Terminal.App.Owned_Image_Data.Move (State.Output, Inflated);
      Inflated_Length := State.Output_Length;
      State.State := Idle;
      Status := Terminal.App.Image_Decode.Decode_Ok;
   exception
      when Storage_Error =>
         Close (State);
         State.Output.Release;
         State.State := Idle;
         Status := Terminal.App.Image_Decode.Decode_Allocation_Failed;
      when Constraint_Error =>
         Close (State);
         State.Output.Release;
         State.State := Idle;
         Status := Terminal.App.Image_Decode.Decode_Invalid_Byte;
   end Finish;
end Terminal.App.Zlib_Inflation;
