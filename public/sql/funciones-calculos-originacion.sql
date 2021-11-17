
--Crear
create or replace
function public.calculos_automatizacion_pruebas (
  p_monto integer,
p_xperiodoPrima integer,
p_tasaInicial numeric,
p_plazo numeric,
p_diasIniciales numeric,
p_vlrCompasSaneamientos numeric,
p_ingresos numeric,
p_descLey numeric,
p_descNomina numeric,
p_pagaduria text 
)
returns table (
r_monto_solicitar int,
r_cuota_corriente int,
r_estudio_credito_iva int,
r_fianza int,
r_gmf4100 int,
r_valor_intereses_iniciales int,
r_prima_anticipada_seguro int,
r_remanente_estimado int,
r_monto_max_desembolsar int
)
language plpgsql
as $function$

declare
-- ============================================================================
-- Autor: Equipo automatizacion Pruebas.
-- Fecha: 08/Nov/2021 Version 1.0 ThainerPerez - Jonathan Varon
-- Se crea la funcion que retorna los calculos de originacion para los simuladores
-- ============================================================================


/*VARIABLES GLOBALES PARA LOS PARAMETROS*/
v_tasa_estudio_credito numeric;

v_tasa_fianza numeric;

v_vlr_mes_dos numeric;

v_tasa_uno numeric = p_tasaInicial / 100 ;

v_tasa_dos numeric;

v_tasaXmillonSeguro numeric;

v_valor_millon numeric = 1000000;

v_iva numeric = 1.19;

v_diasMes numeric = 30;

v_gmf4100 numeric = 0.004;

v_capacidad numeric;

v_colchon numeric;

begin
/*PARAMETROS GLOBALES*/

/*consultar valores capitalizados*/
select
	segunda_tasa,
	estudio_credito,
	fianza,
	mes_cambio_tasa
into
	v_tasa_dos,
	v_tasa_estudio_credito,
	v_tasa_fianza,
	v_vlr_mes_dos
from
	configuracion_capitalizacion_cxc ccc
where
	tasa_inicial = p_tasaInicial;

/*consultar tasaXmillon*/
select
	tasa_millon
into
	v_tasaXmillonSeguro
from
	seguro;

/*consultar colchon*/
select
	pp.valor
into
	v_colchon
from
	pagaduria p
inner join pagaduria_parametro pp on
	pp.id_pagaduria = p.id
inner join parametro pa on
	pa.id = pp.id_parametro
where
	p.nombre = p_pagaduria
	and pa.nombre = 'colchon';

/**********************************CALCULOS DE CONCEPTOS PARA SIMULADORES********************************************/
   
	/*Calcular monto solicitado -  originacion*/
r_monto_solicitar := p_monto + (p_monto * v_tasaXmillonSeguro / v_valor_millon * p_xperiodoPrima)
                + (p_monto * (v_tasa_estudio_credito / 100) * v_iva) + (p_monto * (v_tasa_fianza / 100) * v_iva);

raise notice 'Monto solicitar %',
(r_monto_solicitar);

	/*Calcular cuota corriente -  originacion*/
   if(p_plazo < v_vlr_mes_dos) then
    r_cuota_corriente := r_monto_solicitar / ((power((1 + v_tasa_uno), (p_plazo)) - 1) / (v_tasa_uno * power((1 + v_tasa_uno), (p_plazo))));
else
	v_tasa_dos = v_tasa_dos / 100;
   r_cuota_corriente := round(r_monto_solicitar
                    / ((power((1 + v_tasa_uno), (v_vlr_mes_dos - 1)) - 1) / (v_tasa_uno * power((1 + v_tasa_uno), (v_vlr_mes_dos - 1)))
                    + ((power((1 + v_tasa_dos), (p_plazo - (v_vlr_mes_dos - 1))) - 1)
                    / (v_tasa_dos * power((1 + v_tasa_dos), (p_plazo - (v_vlr_mes_dos - 1)))))
                    / (power((1 + v_tasa_uno), (v_vlr_mes_dos - 1)))));
                   
   /*raise notice '>>>> valor credito %', (r_monto_solicitar);
  raise notice '>>>> valor tasaUno  %', (v_tasa_uno);
 raise notice '>>>> valor mesDos  %', (v_vlr_mes_dos);
 raise notice '>>>> valor tazaDos  %', (v_tasa_dos);
raise notice '>>>> valor plazo  %', (p_plazo);*/
end if;

raise notice 'Cuota Corriente %', (r_cuota_corriente);

	/*Calcular Estudio Credito IVA -  originacion*/
r_estudio_credito_iva := ((p_monto * v_tasa_estudio_credito) / 100) + (((p_monto * v_tasa_estudio_credito) / 100) * (v_iva - 1));

raise notice 'valor Estudio Credito + Iva %', (r_estudio_credito_iva);

	/*Calcular Fianza -  originacion*/
r_fianza := ((p_monto * v_tasa_fianza) / 100) * v_iva;

raise notice 'valor Fianza(s) %',
(r_fianza);

	/*Calcular Gmf4*1000 -  originacion*/
r_gmf4100 := p_vlrCompasSaneamientos * v_gmf4100;

raise notice 'Valor GMF4100 %', (r_gmf4100);

	/*Calular Valor Intereses Iniciales -  originacion*/
r_valor_intereses_iniciales := ((r_monto_solicitar * p_tasaInicial) / 100) * (p_diasIniciales / v_diasMes);

raise notice 'Valor Intereses Iniciales %',
(r_valor_intereses_iniciales);

	/*Calcular Prima Anticipada Seguro -  originacion*/
r_prima_anticipada_seguro := ((p_monto / v_valor_millon)*(v_tasaXmillonSeguro * p_xperiodoPrima));

raise notice 'PrimaSeguro %',
(r_prima_anticipada_seguro);

	/*Calcular Remanente Estimado -  originacion*/

r_remanente_estimado := r_monto_solicitar - (p_vlrCompasSaneamientos + r_gmf4100 + r_prima_anticipada_seguro + r_estudio_credito_iva + r_fianza);

raise notice 'Remanente Estimado %', (r_remanente_estimado);

	/*Calcular Monto Maximo a Desembolsar -  originacion*/

v_capacidad := ((p_ingresos - p_descLey) / 2) - p_descNomina - v_colchon;
--Logica
if (p_plazo < v_vlr_mes_dos) then
	r_monto_max_desembolsar := v_capacidad * ((power((1 + v_tasa_uno),(p_plazo))) - 1) / (v_tasa_uno * power((1 + v_tasa_uno),(p_plazo)));
else 
	r_monto_max_desembolsar := v_capacidad * ((power((1 + v_tasa_uno), (v_vlr_mes_dos - 1))) - 1)
                    / (v_tasa_uno * power((1 + v_tasa_uno), (v_vlr_mes_dos - 1)))
                    + (v_capacidad * ((power((1 + v_tasa_dos), (p_plazo - (v_vlr_mes_dos - 1)))) - 1)
                    / (v_tasa_dos * power((1 + v_tasa_dos), (p_plazo - (v_vlr_mes_dos - 1)))))
                    / power((1 + v_tasa_uno), (v_vlr_mes_dos - 1));
end if;

raise notice 'Monto Maximo a Desembolsar %', (r_monto_max_desembolsar);

/**********************************RETORNO DE : CALCULOS DE CONCEPTOS PARA SIMULADORES********************************************/
return query
select coalesce (r_monto_solicitar,0),
coalesce (r_cuota_corriente,0), 
coalesce (r_estudio_credito_iva,0),
coalesce (r_fianza,0),
coalesce (r_gmf4100,0),
coalesce (r_valor_intereses_iniciales,0),
coalesce (r_prima_anticipada_seguro,0),
coalesce (r_remanente_estimado,0),
coalesce (r_monto_max_desembolsar,0);
end;

$function$
--