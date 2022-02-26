SET search_path TO portfolio_covid;

SELECT *
FROM coviddata
WHERE iso_code LIKE 'USA'
ORDER BY 3,4;


SELECT date, hosp_patients, weekly_hosp_admissions
FROM coviddata
WHERE iso_code LIKE 'USA'
	AND hosp_patients IS NOT NULL
ORDER BY date
	

-- Create view of total cases, deaths, people fully vaccinated per country

CREATE VIEW per_country_cases_vacs_deaths AS
SELECT location, continent, MAX(total_cases) AS totalcases, MAX(people_fully_vaccinated) AS totalvaccinated, MAX(total_deaths) AS totaldeaths
FROM coviddata
WHERE continent IS NOT NULL
GROUP BY location, continent
HAVING MAX(total_cases) IS NOT NULL
ORDER BY MAX(total_cases) DESC;


-- Create view for countries with highest rates of cases, deaths, and fully vaccinated people

CREATE VIEW per_country_cdv_rates AS
SELECT location, continent, MAX(total_cases_per_million) AS case_rate, ROUND(MAX(people_fully_vaccinated_per_hundred)*10000) AS full_vax_rate, MAX(total_deaths_per_million) AS death_rate
FROM coviddata
WHERE continent IS NOT NULL
GROUP BY location, continent
HAVING MAX(total_cases_per_million) IS NOT NULL
ORDER BY MAX(total_cases_per_million) DESC;


-- Select data to determine impact of risk factors on death, ICU admission, and hospitalization rates

CREATE VIEW risk_vs_sev_illness AS
SELECT location, continent, SUM(weekly_hosp_admissions_per_million) AS hosprate, SUM(weekly_icu_admissions_per_million) AS icurate, MAX(total_deaths_per_million) AS deathrate, median_age, aged_65_older, aged_70_older, gdp_per_capita, extreme_poverty, cardiovasc_death_rate, diabetes_prevalence, female_smokers, male_smokers, human_development_index
FROM coviddata
WHERE continent IS NOT NULL
	AND median_age IS NOT NULL
	AND aged_65_older IS NOT NuLL
	AND aged_70_older IS NOT NuLL
	AND gdp_per_capita IS NOT NuLL
	AND extreme_poverty IS NOT NuLL
	AND cardiovasc_death_rate IS NOT NuLL
	AND diabetes_prevalence IS NOT NuLL
	AND female_smokers IS NOT NuLL
	AND male_smokers IS NOT NuLL
	AND human_development_index IS NOT NuLL
GROUP BY location, continent, median_age, aged_65_older, aged_70_older, gdp_per_capita, extreme_poverty, cardiovasc_death_rate, diabetes_prevalence, female_smokers, male_smokers, human_development_index
ORDER BY hosprate DESC;


-- Create view for vaccinations vs hospitalization, ICU, and death rates, and case rate by day globally

CREATE TABLE vax_case_effect
(date date,
 totalvaxtodate double precision,
 totalcasetodate double precision,
 hosppatients double precision,
 icupatients double precision,
 totaldeathstodate double precision
);

INSERT INTO vax_case_effect
SELECT date, SUM(total_vaccinations) AS totalvaxtodate, SUM(total_cases) AS totalcasetodate, MAX(hosp_patients) AS hosppatients, MAX(icu_patients) AS icupatients, SUM(total_deaths) AS totaldeathstodate
FROM coviddata
WHERE continent IS NOT NULL
GROUP BY date;


CREATE VIEW global_vax_vs_sev_illness AS
SELECT date, totalvaxtodate, totalcasetodate, hosppatients, icupatients, totaldeathstodate, totalcasetodate - LAG(totalcasetodate,1) OVER(ORDER BY date) AS caserate, totaldeathstodate - LAG(totaldeathstodate,1) OVER(ORDER BY date) AS deathrate
FROM vax_case_effect
GROUP BY date, totalvaxtodate, totalcasetodate, hosppatients, icupatients, totaldeathstodate
ORDER BY date;


-- Create view for vaccinations vs death rates, and case rates global

CREATE VIEW vax_vs_case_death_country AS
SELECT date, location, continent, SUM(total_vaccinations) OVER (PARTITION BY location ORDER BY location, date) AS countryvaxtodate, SUM(total_cases) OVER (PARTITION BY location ORDER BY location, date) AS countrycasestodate, SUM(total_deaths) OVER (PARTITION BY location ORDER BY location, date) AS countrydeathstodate
FROM coviddata
WHERE continent IS NOT NULL
ORDER BY location, date;



-- Create views with data to show effect of boosters on positive test, hospitalization, and death rates before and after omicron variant in USA; Use 2021-01-12 as variant first identified in USA; start table on 

CREATE VIEW booster_vs_omicron_USA AS
SELECT date, total_boosters, new_cases, weekly_hosp_admissions, new_deaths
FROM coviddata
WHERE iso_code LIKE 'USA'
	AND date >= '2021-12-01'
ORDER BY date;

CREATE VIEW booster_vs_covid_preomicron_USA AS
SELECT date, total_boosters, new_cases, weekly_hosp_admissions, new_deaths
FROM coviddata
WHERE iso_code LIKE 'USA'
	AND date < '2021-12-01'
	AND total_boosters IS NOT NULL
ORDER BY date;


-- Create view to show effect of strict policy on  new cases and deaths for 10 countries with highest population

CREATE VIEW stringency_vs_cases_deaths AS
SELECT date, location, stringency_index, new_cases, new_deaths
FROM coviddata
WHERE location IN(SELECT location
					FROM coviddata
					WHERE continent IS NOT NULL
						AND population IS NOT NULL
					GROUP BY location, population
					ORDER BY population DESC
					LIMIT 10)
ORDER BY population DESC;



-- Create view of excess mortality minus covid deaths (deaths above expected due to other causes; isolation  of elderly, suicides, etc.) vs avg stringency of policy, extreme poverty, and human development index by country

CREATE VIEW excessmortality_vs_risks AS
WITH excessmortality (location, excessmortalitypermil, deathspermil, stringency, extremepoverty, humandevindex)
AS
(
SELECT location, MAX(excess_mortality_cumulative_per_million) AS excessmortalitypermil, MAX(total_deaths_per_million) AS deathspermil, AVG(stringency_index) AS stringency, extreme_poverty, human_development_index
FROM coviddata
WHERE continent IS NOT NULL
	AND extreme_poverty IS NOT NULL
	AND human_development_index IS NOT NULL
	AND excess_mortality_cumulative_per_million IS NOT NULL
	AND stringency_index IS NOT NULL
GROUP BY location, extreme_poverty, human_development_index
)
SELECT *, excessmortalitypermil - deathspermil AS excessmortality_diff
FROM excessmortality
ORDER BY location;


-- Create view to show excess mortality over timespan of pandemic by continent

CREATE VIEW excess_mortality_by_continent AS
SELECT date,continent, SUM(excess_mortality_cumulative) AS excessmortality
FROM coviddata
WHERE excess_mortality_cumulative IS NOT NULL
GROUP BY date, continent
ORDER BY continent, date;



-- Create views for reproductive index vs stringency index over span by country; show effect of lockdowns/closures on reproduction, lag reproduction rate by ~9mo. Second view shows avg reproduction rate vs each countries maximum stringency

CREATE VIEW reprod_stringency_vs_time AS
SELECT date, location, reproduction_rate, LAG(reproduction_rate,-270) OVER(PARTITION BY location ORDER BY date) AS reproduction_lag, stringency_index
FROM coviddata
WHERE continent IS NOT NULL
AND reproduction_rate IS NOT NULL
ORDER BY location, date;


CREATE VIEW reprod_vs_stringency_by_country AS
SELECT location, AVG(reproduction_rate) AS reproduction, MAX(stringency_index) AS stringency
FROM coviddata
WHERE continent IS NOT NULL
	AND reproduction_rate IS NOT NULL
	AND stringency_index IS NOT NULL
GROUP BY location
ORDER BY stringency;










