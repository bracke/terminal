with Terminal.App.Cleanup_Diagnostics;

package body Terminal.App.Inflate_Filter is
   use type Ada.Streams.Stream_Element_Offset;

   procedure Close_Checked
     (State   : in out Decoder;
      Success : out Boolean) is
   begin
      if State.State /= Closed then
         Zlib.Close (State.Filter, Ignore_Error => True);
         State.State := Closed;
      end if;
      Success := True;
   exception
      when E : others =>
         State.State := Failed;
         Success := False;
         Terminal.App.Cleanup_Diagnostics.Note_Failure
           (Terminal.App.Cleanup_Diagnostics.Media_Decoder,
            E,
            "close inflate filter");
   end Close_Checked;

   procedure Close (State : in out Decoder) is
      Ignored : Boolean;
   begin
      Close_Checked (State, Ignored);
   end Close;

   overriding procedure Finalize (State : in out Decoder) is
   begin
      Close (State);
   end Finalize;

   procedure Start
     (State   : in out Decoder;
      Wrapper : Wrapper_Kind;
      Success : out Boolean) is
      Closed_Cleanly : Boolean;
   begin
      Close_Checked (State, Closed_Cleanly);
      if not Closed_Cleanly then
         Success := False;
         return;
      end if;
      Zlib.Inflate_Init
        (State.Filter,
         (case Wrapper is
            when Zlib_Wrapper => Zlib.Zlib_Header,
            when Raw_Deflate => Zlib.Raw_Deflate));
      State.State := Active;
      Success := True;
   exception
      when Zlib.Zlib_Error | Zlib.Status_Error =>
         --  Inflate_Init did not establish a live filter, so there is no
         --  resource for Close to reclaim on this path.
         State.State := Closed;
         Success := False;
   end Start;

   procedure Translate
     (State       : in out Decoder;
      Input       : Ada.Streams.Stream_Element_Array;
      Input_Last  : out Ada.Streams.Stream_Element_Offset;
      Output      : out Ada.Streams.Stream_Element_Array;
      Output_Last : out Ada.Streams.Stream_Element_Offset;
      Success     : out Boolean) is
   begin
      Input_Last := Input'First - 1;
      Output_Last := Output'First - 1;
      if State.State /= Active then
         Success := False;
         return;
      end if;
      Zlib.Translate
        (State.Filter, Input, Input_Last, Output, Output_Last, Zlib.No_Flush);
      Success := True;
   exception
      when Zlib.Zlib_Error | Zlib.Status_Error | Constraint_Error =>
         State.State := Failed;
         Success := False;
   end Translate;

   procedure Finish
     (State       : in out Decoder;
      Output      : out Ada.Streams.Stream_Element_Array;
      Output_Last : out Ada.Streams.Stream_Element_Offset;
      Success     : out Boolean) is
   begin
      Output_Last := Output'First - 1;
      if State.State /= Active then
         Success := False;
         return;
      end if;
      Zlib.Flush (State.Filter, Output, Output_Last, Zlib.Finish);
      Success := True;
   exception
      when Zlib.Zlib_Error | Zlib.Status_Error | Constraint_Error =>
         State.State := Failed;
         Success := False;
   end Finish;

   function Ended (State : Decoder) return Boolean is
     (State.State = Active and then Zlib.Stream_End (State.Filter));
end Terminal.App.Inflate_Filter;
