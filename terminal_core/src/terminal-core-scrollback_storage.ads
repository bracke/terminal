private package Terminal.Core.Scrollback_Storage is
   procedure Clear
     (State         : in out Scrollback_Runtime_State;
      Current_Style : Style);
   function Index
     (State : Scrollback_Runtime_State;
      Cols  : Positive;
      Row   : Positive;
      Col   : Positive) return Positive;
   procedure Append_Row
     (State          : in out Scrollback_Runtime_State;
      Cols           : Positive;
      Current_Style  : Style;
      Queue_Overflow : in out Natural;
      Cells          : Stored_Cell_Array_Access;
      Source         : Positive);
end Terminal.Core.Scrollback_Storage;
