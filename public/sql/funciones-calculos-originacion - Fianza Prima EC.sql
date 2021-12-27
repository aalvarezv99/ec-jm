--Descripcion de Parametros
/* Entradas como parametros
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
*/
--Probar Funcion
--select * from public.calculos_automatizacion_pruebas (19989718,24,1.8,25,120,0,3700000,0,0,'ALCALDÍA MUNICIPAL DE ARMENIA NÓMINA JUBILADOS');
--Eliminar Funcion 
--DROP FUNCTION calculos_automatizacion_pruebas(integer, integer, numeric, numeric, numeric, numeric, numeric, numeric, numeric, text);
--Crear Funcion
CREATE OR REPLACE FUNCTION public.calculos_automatizacion_pruebas(p_monto integer,
p_xperiodoprima integer,
p_tasainicial NUMERIC,
p_plazo NUMERIC,
p_diasiniciales NUMERIC,
p_vlrcompassaneamientos NUMERIC,
p_ingresos NUMERIC,
p_descley NUMERIC,
p_descnomina NUMERIC,
p_pagaduria text)
 RETURNS TABLE(
r_monto_solicitar integer,
r_cuota_corriente integer,
r_estudio_credito_iva integer,
r_fianza integer,
r_gmf4100 integer,
r_valor_intereses_iniciales integer,
r_prima_anticipada_seguro integer,
r_remanente_estimado integer,
r_monto_max_desembolsar integer,
r_capacidad_cliente integer
--v_monto_solicitar_pantalla NUMERIC
)
 LANGUAGE plpgsql
AS $function$

declare
-- ============================================================================
-- Autor: Equipo automatizacion Pruebas.
-- Fecha: 08/Nov/2021 Version 1.0 ThainerPerez - Jonathan Varon
-- Se crea la funcion que retorna los calculos de originacion para los simuladores
-- ============================================================================


/*VARIABLES GLOBALES PARA LOS PARAMETROS*/

v_monto_solicitar_pantalla numeric;

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

-- ============================================================================
-- Autor: Equipo automatizacion Pruebas.
-- Fecha: 27/Dic/2021 Version 1.1 Jonathan Varon
-- Se crea la funcion que retorna los calculos de originacion para los simuladores con el nuevo Calculo
-- ============================================================================

	/*Calcular monto solicitado -  originacion*/
/*r_monto_solicitar := p_monto + (p_monto * v_tasaXmillonSeguro / v_valor_millon * p_xperiodoPrima)
                + (p_monto * (v_tasa_estudio_credito / 100) * v_iva) + (p_monto * (v_tasa_fianza / 100) * v_iva);
*/
r_monto_solicitar := p_monto;
raise notice 'Monto solicitar %', (r_monto_solicitar);


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

raise notice 'Valor Intereses Iniciales %',(r_valor_intereses_iniciales);

	/*Calcular Prima Anticipada Seguro -  originacion*/
r_prima_anticipada_seguro := ((p_monto / v_valor_millon)*(v_tasaXmillonSeguro * p_xperiodoPrima));

raise notice 'PrimaSeguro %',(r_prima_anticipada_seguro);

	/*Calcular Remanente Estimado -  originacion*/

r_remanente_estimado := r_monto_solicitar - (p_vlrCompasSaneamientos + r_gmf4100 + r_prima_anticipada_seguro + r_estudio_credito_iva + r_fianza);

raise notice 'Remanente Estimado %', (r_remanente_estimado);

	/* Calcular Valor Pantalla  - Monto del credito*/

v_monto_solicitar_pantalla := round (r_remanente_estimado/((1-(((v_tasaXmillonSeguro/1000)/1000000)*1000)*p_xperiodoprima)-((v_tasa_fianza/100)*1.19)-(v_tasa_estudio_credito*1.19)));
raise notice 'Valor Monto Pantalla %', (v_monto_solicitar_pantalla);

	/* Validacion Comparacion monto catulado y monto pantalla */
if (v_monto_solicitar_pantalla = p_monto) then
	r_monto_solicitar := v_monto_solicitar_pantalla;

	raise notice 'PASS - Validacion Comparacion monto catulado y monto pantalla %', (r_monto_solicitar);
else 
	raise notice 'FAILED - Validacion Comparacion monto catulado y monto pantalla %', (r_monto_solicitar);
end if;

	/*Calcular Monto Maximo a Desembolsar -  originacion*/

v_capacidad := ((p_ingresos - p_descLey) / 2) - p_descNomina - v_colchon;
raise notice 'Capacidad Cliente %', (v_capacidad);

r_capacidad_cliente := v_capacidad;
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
coalesce (r_monto_max_desembolsar,0),
coalesce (r_capacidad_cliente,0);
--coalesce (v_monto_solicitar_pantalla,0);
end;

$function$
;