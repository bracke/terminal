private package Terminal.Core.Hyperlink_Store is
   function Intern
     (State      : in out Hyperlink_Runtime_State;
      Primary    : Stored_Cell_Array_Access;
      Alternate  : Stored_Cell_Array_Access;
      Scrollback : Scrollback_Runtime_State;
      Cols       : Positive;
      Value      : Hyperlink) return Stored_Hyperlink_Access;
   function Intern_Snapshot
     (State : in out Hyperlink_Runtime_State;
      Value : Hyperlink) return Stored_Hyperlink_Access;
   procedure Release_Snapshot
     (State : in out Hyperlink_Runtime_State;
      Item  : in out Stored_Hyperlink_Access);
   procedure Release_All (State : in out Hyperlink_Runtime_State);
end Terminal.Core.Hyperlink_Store;
