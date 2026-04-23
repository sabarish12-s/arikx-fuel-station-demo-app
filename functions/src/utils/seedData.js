const DEFAULT_STATION = {
  id: 'station-hq-01',
  name: 'RK Fuels Station HQ-01',
  code: 'HQ-01',
  city: 'Chennai',
  shifts: ['daily'],
  pumps: [
    {
      id: 'pump1',
      label: 'Pump 1',
      nozzles: [
        {fuelTypeId: 'petrol', label: 'Petrol Gun'},
        {fuelTypeId: 'diesel', label: 'Diesel Gun'},
      ],
    },
    {
      id: 'pump2',
      label: 'Pump 2',
      nozzles: [
        {fuelTypeId: 'petrol', label: 'Petrol Gun'},
        {fuelTypeId: 'diesel', label: 'Diesel Gun'},
        {fuelTypeId: 'two_t_oil', label: '2T Oil Gun'},
      ],
    },
    {
      id: 'pump3',
      label: 'Pump 3',
      nozzles: [
        {fuelTypeId: 'petrol', label: 'Petrol Gun'},
        {fuelTypeId: 'diesel', label: 'Diesel Gun'},
      ],
    },
  ],
  baseReadings: {
    pump1: {petrol: 4200, diesel: 3100, twoT: 0},
    pump2: {petrol: 4150, diesel: 3050, twoT: 600},
    pump3: {petrol: 4100, diesel: 3000, twoT: 0},
  },
  inventoryPlanning: {
    openingStock: {
      petrol: 0,
      diesel: 0,
      two_t_oil: 0,
    },
    currentStock: {
      petrol: 0,
      diesel: 0,
      two_t_oil: 0,
    },
    deliveryLeadDays: 2,
    alertBeforeDays: 1,
    updatedAt: '',
  },
  salesmen: [],
};

const DEFAULT_FUEL_TYPES = [
  {
    id: 'petrol',
    name: 'Petrol',
    shortName: 'P95',
    description: 'Standard octane petrol for daily passenger vehicles.',
    color: '#1E5CBA',
    icon: 'local_gas_station',
    active: true,
  },
  {
    id: 'diesel',
    name: 'Diesel',
    shortName: 'HSD',
    description: 'High-speed diesel for commercial and passenger use.',
    color: '#006C5C',
    icon: 'oil_barrel',
    active: true,
  },
  {
    id: 'two_t_oil',
    name: '2T Oil',
    shortName: '2T',
    description: 'Two-stroke engine oil dispensed only through Pump 2.',
    color: '#B45309',
    icon: 'opacity',
    active: true,
  },
];

const DEFAULT_FUEL_PRICES = [
  {
    fuelTypeId: 'petrol',
    costPrice: 98.45,
    sellingPrice: 104.75,
    updatedBy: 'system',
  },
  {
    fuelTypeId: 'diesel',
    costPrice: 89.1,
    sellingPrice: 95.2,
    updatedBy: 'system',
  },
  {
    fuelTypeId: 'two_t_oil',
    costPrice: 138.5,
    sellingPrice: 149.0,
    updatedBy: 'system',
  },
];

module.exports = {
  DEFAULT_FUEL_PRICES,
  DEFAULT_FUEL_TYPES,
  DEFAULT_STATION,
};
