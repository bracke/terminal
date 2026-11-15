with Terminal.Core.Graphics_Runtime;

separate (Terminal.Core)
procedure Feed
  (T      : in out Terminal;
   Data   : Core_Byte_Array;
   Status : out Feed_Status)
is
   Overflowed : Boolean := False;
   Recovered  : Boolean := False;
begin
   if not T.Initialized then
      Status := Invalid_State;
      return;
   end if;

   T.Graphics.Queue_Overflowed := False;

   if T.Graphics.Input_Blocked then
      Status :=
        (if Append_Deferred_Input (T, Data) then Ok else Parser_Overflow);
      return;
   end if;

   declare
      Passthrough        : Core_Byte_Array_Access := null;
      Passthrough_Length : Natural := 0;
      Passthrough_Budget : Natural := T.Graphics.Limits.Transaction_Length;

   begin
      for Data_Index in Data'Range loop
         Process_Feed_Byte
           (T, Data (Data_Index), Overflowed, Recovered,
            Passthrough, Passthrough_Length, Passthrough_Budget);
         if Passthrough /= null then
            Drain_Tmux_Passthrough
              (T, Passthrough, Passthrough_Length, Passthrough_Budget,
               Overflowed, Recovered);
         end if;
         if T.Graphics.Input_Blocked then
            if Data_Index < Data'Last
              and then not Append_Deferred_Input
                (T, Data (Data_Index + 1 .. Data'Last))
            then
               Overflowed := True;
            end if;
            exit;
         end if;
      end loop;
   exception
      when others =>
         Storage.Release (Passthrough);
         raise;
   end;

   if Overflowed or else T.Graphics.Queue_Overflowed then
      Status := Parser_Overflow;
   elsif Recovered then
      Status := Parser_Recovered;
   else
      Status := Ok;
   end if;
exception
   when others =>
      Response_Facade.Abort_Transaction (T);
      raise;
end Feed;
