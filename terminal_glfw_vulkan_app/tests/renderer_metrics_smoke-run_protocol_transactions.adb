separate (Renderer_Metrics_Smoke)
procedure Run_Protocol_Transactions (Context : in out Suite_Context) is
begin
   Run_Query_And_Validation_Cases (Context);
   Run_Quota_And_Segmentation_Cases (Context);
   Run_Large_Payload_Cases (Context);
   Run_Raw_And_ITerm2_Cases (Context);
   Run_Encoded_And_Sixel_Cases (Context);
   Run_Protocol_Diagnostic_Cases (Context);
end Run_Protocol_Transactions;
