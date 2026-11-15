private package Terminal.Core.Response_Queries is
   procedure Queue_Device_Status_Report
     (T    : in out Terminal;
      Kind : Natural);

   procedure Queue_Window_Operation_Report
     (T      : in out Terminal;
      Number : Natural);

   function Mode_Report_State
     (T       : Terminal;
      Prefix  : Standard.Character;
      Number  : Natural) return Natural;

   procedure Queue_Mode_Report (T : in out Terminal);
end Terminal.Core.Response_Queries;
