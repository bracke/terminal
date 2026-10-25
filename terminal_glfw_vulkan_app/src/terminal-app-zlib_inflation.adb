with Ada.Unchecked_Deallocation;

package body Terminal.App.Zlib_Inflation is
   use type Ada.Streams.Stream_Element_Offset;
   use type Terminal.App.Render_Model.Image_Data_Access;

   procedure Free_Image_Data is new Ada.Unchecked_Deallocation
     (Terminal.Common.Bytes.Byte_Array,
      Terminal.App.Render_Model.Image_Data_Access);

   procedure Close (State : in out Decoder) is
   begin
      if State.Opened then
         Zlib.Close (State.Filter, Ignore_Error => True);
         State.Opened := False;
      end if;
   exception
      when others =>
         State.Opened := False;
   end Close;

   overriding procedure Finalize (State : in out Decoder) is
   begin
      Close (State);
      Free_Image_Data (State.Output);
   end Finalize;

   procedure Fail
     (State  : in out Decoder;
      Status : Terminal.App.Image_Decode.Status) is
   begin
      State.Failed := True;
      State.Failure_Status := Status;
   end Fail;

   procedure Consume
     (State : in out Decoder;
      Data  : Ada.Streams.Stream_Element_Array;
      Last  : Ada.Streams.Stream_Element_Offset)
   is
   begin
      if Last < Data'First then
         return;
      end if;
      for I in Data'First .. Last loop
         if State.Output_Length = State.Maximum_Length then
            Fail (State, Terminal.App.Image_Decode.Decode_Too_Large);
            return;
         end if;
         State.Output_Length := State.Output_Length + 1;
         State.Output (State.Output_Length) :=
           Terminal.Common.Bytes.Byte (Data (I));
      end loop;
   end Consume;

   procedure Translate_Input (State : in out Decoder) is
      First : Ada.Streams.Stream_Element_Offset := State.Input'First;
      Last  : constant Ada.Streams.Stream_Element_Offset :=
        State.Input'First
        + Ada.Streams.Stream_Element_Offset (State.Input_Length) - 1;
   begin
      while not State.Failed and then First <= Last loop
         declare
            Output : Ada.Streams.Stream_Element_Array
              (1 .. Ada.Streams.Stream_Element_Offset (Buffer_Size));
            Input_Last  : Ada.Streams.Stream_Element_Offset;
            Output_Last : Ada.Streams.Stream_Element_Offset;
            Before      : constant Ada.Streams.Stream_Element_Offset := First;
         begin
            Zlib.Translate
              (State.Filter,
               State.Input (First .. Last),
               Input_Last,
               Output,
               Output_Last,
               Zlib.No_Flush);
            Consume (State, Output, Output_Last);
            exit when State.Failed;
            if Input_Last >= First then
               First := Input_Last + 1;
            elsif Output_Last < Output'First then
               Fail (State, Terminal.App.Image_Decode.Decode_Invalid_Byte);
            end if;
            if Zlib.Stream_End (State.Filter) then
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
      when Zlib.Zlib_Error | Zlib.Status_Error | Constraint_Error =>
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
      Free_Image_Data (State.Output);
      State.Ready := False;
      State.Failed := False;
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
      State.Output :=
        new Terminal.Common.Bytes.Byte_Array (1 .. Maximum_Length);
      Zlib.Inflate_Init (State.Filter, Zlib.Zlib_Header);
      State.Opened := True;
      State.Ready := True;
      Status := Terminal.App.Image_Decode.Decode_Ok;
   exception
      when Storage_Error =>
         Close (State);
         Free_Image_Data (State.Output);
         Status := Terminal.App.Image_Decode.Decode_Allocation_Failed;
      when Zlib.Zlib_Error | Zlib.Status_Error =>
         Close (State);
         Free_Image_Data (State.Output);
         Status := Terminal.App.Image_Decode.Decode_Invalid_Byte;
   end Start;

   procedure Push
     (State    : in out Decoder;
      Value    : Terminal.Common.Bytes.Byte;
      Continue : in out Boolean) is
   begin
      if not State.Ready or else State.Failed then
         Continue := False;
         return;
      elsif Zlib.Stream_End (State.Filter) then
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
      Continue := not State.Failed;
   end Push;

   procedure Finish
     (State           : in out Decoder;
      Inflated        : out Terminal.App.Render_Model.Image_Data_Access;
      Inflated_Length : out Natural;
      Status          : out Terminal.App.Image_Decode.Status) is
   begin
      Inflated := null;
      Inflated_Length := 0;
      Status := Terminal.App.Image_Decode.Decode_Invalid_Byte;
      if not State.Ready then
         return;
      end if;
      if State.Input_Length > 0 and then not State.Failed then
         Translate_Input (State);
      end if;
      for Pass in 1 .. State.Maximum_Length / Buffer_Size + 4 loop
         exit when State.Failed or else Zlib.Stream_End (State.Filter);
         declare
            Output : Ada.Streams.Stream_Element_Array
              (1 .. Ada.Streams.Stream_Element_Offset (Buffer_Size));
            Output_Last : Ada.Streams.Stream_Element_Offset;
         begin
            Zlib.Flush (State.Filter, Output, Output_Last, Zlib.Finish);
            Consume (State, Output, Output_Last);
            if not State.Failed
              and then Output_Last < Output'First
              and then not Zlib.Stream_End (State.Filter)
            then
               Fail (State, Terminal.App.Image_Decode.Decode_Invalid_Byte);
            end if;
         end;
      end loop;
      if not State.Failed and then not Zlib.Stream_End (State.Filter) then
         Fail (State, Terminal.App.Image_Decode.Decode_Invalid_Byte);
      elsif not State.Failed and then State.Output_Length = 0 then
         Fail (State, Terminal.App.Image_Decode.Decode_Invalid_Byte);
      elsif not State.Failed
        and then State.Exact_Length
        and then State.Output_Length /= State.Maximum_Length
      then
         Fail (State, Terminal.App.Image_Decode.Decode_Invalid_Byte);
      end if;
      Close (State);
      State.Ready := False;
      if State.Failed then
         Status := State.Failure_Status;
         Free_Image_Data (State.Output);
         return;
      end if;
      Inflated := State.Output;
      Inflated_Length := State.Output_Length;
      State.Output := null;
      Status := Terminal.App.Image_Decode.Decode_Ok;
   exception
      when Storage_Error =>
         Close (State);
         Free_Image_Data (State.Output);
         State.Ready := False;
         Status := Terminal.App.Image_Decode.Decode_Allocation_Failed;
      when Zlib.Zlib_Error | Zlib.Status_Error | Constraint_Error =>
         Close (State);
         Free_Image_Data (State.Output);
         State.Ready := False;
         Status := Terminal.App.Image_Decode.Decode_Invalid_Byte;
   end Finish;
end Terminal.App.Zlib_Inflation;
