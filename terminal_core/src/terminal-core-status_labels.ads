package Terminal.Core.Status_Labels is
   function Initialize_Label (Status : Initialize_Status) return String;
   function Feed_Label (Status : Feed_Status) return String;
   function Diagnostics_Label
     (Diagnostics : Diagnostic_Snapshot) return String;
end Terminal.Core.Status_Labels;
