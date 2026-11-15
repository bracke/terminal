with Ada.Finalization;

private package Terminal.App.Child_Tracker is
   Max_Admission_Load   : constant := 64;
   Max_Tracked_Children : constant := 256;

   type Process_ID is range 0 .. Long_Long_Integer'Last;
   type Process_ID_Array is
     array (Positive range 1 .. Max_Tracked_Children) of Process_ID;
   type Boolean_Array is
     array (Positive range 1 .. Max_Tracked_Children) of Boolean;

   type Reservation is new Ada.Finalization.Limited_Controlled with private;

   protected type Registry is
      function Count return Natural;
      function Admission_Load return Natural;
      procedure Reserve (Item : in out Reservation);
      procedure Commit
        (Process : Process_ID;
         Item    : in out Reservation);
      procedure Cancel (Item : in out Reservation);
      procedure Snapshot
        (Items : out Process_ID_Array;
         Count : out Natural);
      procedure Note_Poll_Error
        (Process      : Process_ID;
         First_Report : out Boolean);
      procedure Note_Poll_Success (Process : Process_ID);
      procedure Remove (Process : Process_ID);
   private
      Items                : Process_ID_Array := (others => 0);
      Poll_Error_Reported  : Boolean_Array := (others => False);
      Counts_Against_Limit : Boolean_Array := (others => False);
      Item_Count           : Natural := 0;
      Admission_Load_Value : Natural := 0;
      Reservations         : Natural := 0;
   end Registry;

   function Granted (Item : Reservation) return Boolean;

private
   type Registry_Access is access all Registry;
   type Reservation is new Ada.Finalization.Limited_Controlled with record
      Owner  : Registry_Access := null;
      Active : Boolean := False;
   end record;
   overriding procedure Finalize (Item : in out Reservation);
end Terminal.App.Child_Tracker;
